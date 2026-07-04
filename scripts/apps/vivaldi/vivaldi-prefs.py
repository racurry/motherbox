#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["websockets"]
# ///
"""Manage Vivaldi settings declaratively via its internal prefs API.

Vivaldi keeps its settings inside the profile's Preferences JSON, which the
browser rewrites constantly, so the file itself can't be safely managed.
This tool keeps desired values in a standalone JSON file (dotted pref path
-> value) and writes them through vivaldi.prefs.set over the DevTools
protocol, so a bad value produces an API error instead of a corrupted
profile.

Commands:
  dump    - Capture current values of managed paths from Preferences
            (list paths to start managing them)
  diff    - Show which managed paths differ from current Preferences
  apply   - Write differing values via vivaldi.prefs.set. Restarts Vivaldi
            with a temporary local debug port, then restarts it clean.
  ls      - Explore pref paths in a profile's Preferences; marks paths
            already tracked in the values file
  compare - Show pref differences between two profiles (read-only,
            defaults to the vivaldi.* subtree)

Profiles: all commands target one profile (--profile NAME, default
"Default"). The values file is shared across profiles by design — apply
it to each profile to keep them in sync; pass --file for per-profile
divergence. Note dump captures FROM the given profile INTO the values
file, overwriting it.

Paths must be registered prefs — the exact granularity Vivaldi registers
them at, discoverable only by trying. Both coarser (vivaldi.theme) and
finer (vivaldi.theme.schedule.o_s.dark) than the registered pref
(vivaldi.theme.schedule.o_s) are rejected with "The pref api is not
allowed to access ..." — a loud, harmless error; adjust and re-apply.

Suggested starter paths:
  vivaldi.actions               keyboard shortcuts and mouse gestures
  vivaldi.themes.user           custom themes
  vivaldi.theme.schedule.o_s    scheduled dark/light theme ids
  vivaldi.theme.dim_blurred     dim UI while window is blurred
"""

import argparse
import glob
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from websockets.sync.client import connect

DEFAULT_VALUES_PATH = Path(__file__).resolve().parent / "vivaldi-prefs.json"
VIVALDI_USER_DATA = Path.home() / "Library" / "Application Support" / "Vivaldi"
DEFAULT_PORT = 9222

MISSING = object()

SET_AND_GET_EXPR = """
(async () => {{
  const path = {path_json};
  const value = {value_json};
  vivaldi.prefs.set({{ path, value }});
  await new Promise(r => setTimeout(r, 150));
  const got = await new Promise((res, rej) =>
    vivaldi.prefs.get(path, v => {{
      const err = chrome.runtime.lastError;
      if (err) rej(new Error(err.message)); else res(v);
    }}));
  // get returns {{ defaultValue, value }}, not the bare value; value can be
  // absent (e.g. the browser refused to store a user value) — always emit it
  const hasValue = !!got && got.value !== undefined;
  return JSON.stringify({{
    missing: got === undefined,
    hasValue,
    value: hasValue ? got.value : null,
  }});
}})()
"""


def abbreviate(value, limit: int = 100) -> str:
    text = json.dumps(value)
    return text if len(text) <= limit else text[: limit - 1] + "…"


# The Preferences JSON stores enum prefs as numbers, but vivaldi.prefs.set
# only accepts the enum's string name (raw numbers are silently refused).
# The name<->number maps ship with the app in prefs_definitions.json.
PREFS_DEFINITIONS_GLOB = (
    "/Applications/Vivaldi.app/Contents/Frameworks/"
    "Vivaldi Framework.framework/Versions/*/Resources/vivaldi/prefs_definitions.json"
)

_enum_maps: dict | None = None


def enum_values(path: str) -> dict | None:
    """Return the name -> number map if path is an enum pref, else None."""
    global _enum_maps
    if _enum_maps is None:
        _enum_maps = {}
        matches = sorted(glob.glob(PREFS_DEFINITIONS_GLOB.replace("/*/", "/Current/")))
        matches = matches or sorted(glob.glob(PREFS_DEFINITIONS_GLOB))
        if not matches:
            print("note: prefs_definitions.json not found in Vivaldi.app; "
                  "enum prefs cannot be translated and will fail to set")
        else:
            def collect(node, prefix):
                if not isinstance(node, dict):
                    return
                if node.get("type") == "enum" and isinstance(node.get("enum_values"), dict):
                    _enum_maps[prefix] = node["enum_values"]
                    return
                for key, child in node.items():
                    collect(child, f"{prefix}.{key}" if prefix else key)

            collect(json.loads(Path(matches[-1]).read_text()), "")
    return _enum_maps.get(path)


def die(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def read_preferences(profile_dir: Path) -> dict:
    prefs_path = profile_dir / "Preferences"
    if not prefs_path.exists():
        die(f"no Preferences file at {prefs_path}")
    return json.loads(prefs_path.read_text())


def walk(prefs: dict, path: str):
    node = prefs
    for part in path.split("."):
        if not isinstance(node, dict) or part not in node:
            return MISSING
        node = node[part]
    return node


def load_values(values_path: Path) -> dict:
    if not values_path.exists():
        die(f"no values file at {values_path} — run `vivaldi-prefs dump <path>...` first")
    return json.loads(values_path.read_text())


def load_values_optional(values_path: Path) -> dict:
    return json.loads(values_path.read_text()) if values_path.exists() else {}


def tracked_marker(path: str, values: dict) -> str:
    if any(path == v or path.startswith(v + ".") for v in values):
        return "tracked"
    if any(v.startswith(path + ".") for v in values):
        return "partial"
    return ""


# --- browser process management ---


def vivaldi_running() -> bool:
    return subprocess.run(["pgrep", "-x", "Vivaldi"], capture_output=True).returncode == 0


def quit_vivaldi() -> None:
    subprocess.run(["osascript", "-e", 'tell application "Vivaldi" to quit'], check=True)
    deadline = time.monotonic() + 30
    while vivaldi_running():
        if time.monotonic() > deadline:
            die("Vivaldi did not quit within 30s")
        time.sleep(0.3)


def launch_vivaldi(extra_args: list[str]) -> None:
    cmd = ["open", "-a", "Vivaldi"]
    if extra_args:
        cmd += ["--args", *extra_args]
    subprocess.run(cmd, check=True)


# --- DevTools protocol ---


def http_json(port: int, endpoint: str, timeout: float = 1.0):
    with urllib.request.urlopen(
        f"http://127.0.0.1:{port}/json/{endpoint}", timeout=timeout
    ) as resp:
        return json.loads(resp.read())


def endpoint_up(port: int) -> bool:
    try:
        http_json(port, "version")
        return True
    except (urllib.error.URLError, TimeoutError, OSError):
        return False


def find_ui_targets(port: int) -> list[str]:
    return [
        t["webSocketDebuggerUrl"]
        for t in http_json(port, "list")
        if t.get("url", "").endswith(("/window.html", "/browser.html"))
    ]


def restart_with_debug_port(port: int, profile_name: str) -> None:
    if vivaldi_running():
        print(f"Restarting Vivaldi into profile {profile_name!r} with a temporary debug port ({port})...")
        quit_vivaldi()
    else:
        print(f"Starting Vivaldi into profile {profile_name!r} with a temporary debug port ({port})...")
    launch_vivaldi(
        [f"--remote-debugging-port={port}", f"--profile-directory={profile_name}"]
    )
    deadline = time.monotonic() + 30
    while not endpoint_up(port):
        if time.monotonic() > deadline:
            die(f"debug endpoint on port {port} did not come up within 30s")
        time.sleep(0.3)


# getUserProfiles computes `active` relative to the calling window's profile,
# so with activeOnly=true the single entry is this window's own profile.
# Match on path (unique), not name (falls back to the sign-in username).
PROFILE_ID_EXPR = r"""
new Promise((res, rej) => {
  if (typeof vivaldi === 'undefined' || !vivaldi.runtimePrivate) { res(null); return; }
  vivaldi.runtimePrivate.getUserProfiles(true, profiles => {
    const err = chrome.runtime.lastError;
    if (err) { rej(new Error(err.message)); return; }
    res(profiles && profiles[0] ? profiles[0].path : null);
  });
})
"""


def profile_of_session(session: "CdpSession") -> str | None:
    path = session.evaluate(PROFILE_ID_EXPR)
    return Path(path).name if path else None


def scan_for_profile(port: int, profile_name: str, timeout: float):
    """Find the UI window whose own profile matches; returns (ws, session) or None."""
    deadline = time.monotonic() + timeout
    while True:
        for ws_url in find_ui_targets(port):
            ws = connect(ws_url, max_size=50 * 1024 * 1024, open_timeout=10)
            session = CdpSession(ws)
            try:
                window_profile = profile_of_session(session)
            except RuntimeError as exc:
                print(f"note: skipping UI window that failed profile check: {exc}")
                window_profile = None
            if window_profile == profile_name:
                return ws, session
            ws.close()
        if time.monotonic() > deadline:
            return None
        time.sleep(0.5)


def connect_profile_ui(port: int, profile_name: str):
    """Attach to the UI window of the given profile, relaunching Vivaldi as needed."""
    fresh = not endpoint_up(port)
    if fresh:
        restart_with_debug_port(port, profile_name)
    found = scan_for_profile(port, profile_name, timeout=30 if fresh else 5)
    if not found and not fresh:
        print(f"No open window for profile {profile_name!r}; relaunching into it...")
        restart_with_debug_port(port, profile_name)
        found = scan_for_profile(port, profile_name, timeout=30)
    if not found:
        die(f"could not find a Vivaldi UI window for profile {profile_name!r}")
    return found


class CdpSession:
    def __init__(self, ws):
        self.ws = ws
        self.next_id = 1

    def evaluate(self, expression: str):
        msg_id = self.next_id
        self.next_id += 1
        self.ws.send(
            json.dumps(
                {
                    "id": msg_id,
                    "method": "Runtime.evaluate",
                    "params": {
                        "expression": expression,
                        "awaitPromise": True,
                        "returnByValue": True,
                    },
                }
            )
        )
        while True:
            reply = json.loads(self.ws.recv(timeout=30))
            if reply.get("id") == msg_id:
                break
        if "error" in reply:
            raise RuntimeError(f"CDP error: {reply['error']}")
        result = reply["result"]
        if "exceptionDetails" in result:
            details = result["exceptionDetails"]
            description = details.get("exception", {}).get(
                "description", details.get("text", "unknown error")
            )
            raise RuntimeError(description)
        return result["result"].get("value")


def set_pref(session: CdpSession, path: str, value):
    api_value = value
    enums = enum_values(path)
    if enums is not None and isinstance(value, int) and not isinstance(value, bool):
        names = [name for name, num in enums.items() if num == value]
        if not names:
            raise RuntimeError(f"{path}: {value} not a value of enum {enums}")
        api_value = names[0]
    expr = SET_AND_GET_EXPR.format(
        path_json=json.dumps(path), value_json=json.dumps(api_value)
    )
    outcome = json.loads(session.evaluate(expr))
    got = outcome.get("value")
    if enums is not None and isinstance(got, str) and got in enums:
        outcome["value"] = enums[got]
    if outcome["missing"]:
        raise RuntimeError(f"{path}: pref unknown to vivaldi.prefs after set")
    if not outcome["hasValue"]:
        raise RuntimeError(
            f"{path}: browser did not store a user value (set silently refused)"
        )
    if outcome["value"] != value:
        raise RuntimeError(
            f"{path}: readback mismatch — got {abbreviate(outcome['value'])}, "
            f"want {abbreviate(value)}"
        )


# --- commands ---


def cmd_dump(args) -> int:
    existing = json.loads(args.file.read_text()) if args.file.exists() else {}
    paths = sorted(set(existing) | set(args.paths))
    if not paths:
        die("no managed paths yet — list paths to dump, e.g. vivaldi.actions")
    prefs = read_preferences(args.profile_dir)
    values = {}
    for path in paths:
        value = walk(prefs, path)
        if value is MISSING:
            die(f"{path}: not found in Preferences")
        values[path] = value
        if path not in existing:
            status = "added"
        elif existing[path] != value:
            status = "updated"
        else:
            status = "unchanged"
        print(f"{status:9}  {path}")
    args.file.parent.mkdir(parents=True, exist_ok=True)
    args.file.write_text(json.dumps(values, indent=2, sort_keys=True) + "\n")
    print(f"\nwrote {args.file}")
    return 0


def cmd_ls(args) -> int:
    values = load_values_optional(args.file)
    prefs = read_preferences(args.profile_dir)
    node = walk(prefs, args.path) if args.path else prefs
    if node is MISSING:
        die(f"{args.path}: not found in Preferences")
    if not isinstance(node, dict):
        print(abbreviate(node, 500))
        return 0
    for key in sorted(node):
        child = node[key]
        dotted = f"{args.path}.{key}" if args.path else key
        if isinstance(child, dict):
            summary = f"{{...}} {len(child)} keys"
        elif isinstance(child, list):
            summary = f"[...] {len(child)} items"
        else:
            summary = abbreviate(child)
        print(f"{tracked_marker(dotted, values):8} {dotted:<50} {summary}")
    return 0


def cmd_compare(args) -> int:
    values = load_values_optional(args.file)
    base_name = args.profile_dir.name
    base = read_preferences(args.profile_dir)
    other = read_preferences(VIVALDI_USER_DATA / args.other)
    base_node = walk(base, args.path) if args.path else base
    other_node = walk(other, args.path) if args.path else other
    differences = []

    def visit(path, a, b):
        if a == b:
            return
        if isinstance(a, dict) and isinstance(b, dict):
            for key in sorted(set(a) | set(b)):
                child_path = f"{path}.{key}" if path else key
                if key not in a:
                    differences.append((child_path, MISSING, b[key]))
                elif key not in b:
                    differences.append((child_path, a[key], MISSING))
                else:
                    visit(child_path, a[key], b[key])
        else:
            differences.append((path, a, b))

    visit(
        args.path or "",
        {} if base_node is MISSING else base_node,
        {} if other_node is MISSING else other_node,
    )
    if not differences:
        print(f"no differences under {args.path or '(root)'}")
        return 0
    for path, a, b in differences:
        if a is MISSING:
            detail = f"only in {args.other}: {abbreviate(b)}"
        elif b is MISSING:
            detail = f"only in {base_name}: {abbreviate(a)}"
        else:
            detail = f"{base_name}: {abbreviate(a)}  |  {args.other}: {abbreviate(b)}"
        print(f"{tracked_marker(path, values):8} {path:<50} {detail}")
    return 1


def pending_changes(values: dict, prefs: dict) -> dict:
    return {p: v for p, v in values.items() if walk(prefs, p) != v}


def cmd_diff(args) -> int:
    values = load_values(args.file)
    prefs = read_preferences(args.profile_dir)
    pending = pending_changes(values, prefs)
    for path in sorted(values):
        if path not in pending:
            status = "equal"
        elif walk(prefs, path) is MISSING:
            status = "MISSING"
        else:
            status = "DIFFERS"
        print(f"{status:8}  {path}")
    return 1 if pending else 0


def cmd_apply(args) -> int:
    values = load_values(args.file)
    prefs = read_preferences(args.profile_dir)
    pending = pending_changes(values, prefs)
    if not pending:
        print("all managed prefs already match; nothing to do")
        return 0

    profile_name = args.profile_dir.name
    ws, session = connect_profile_ui(args.port, profile_name)
    failures = 0
    try:
        for path in sorted(pending):
            try:
                set_pref(session, path, pending[path])
                print(f"set       {path}")
            except RuntimeError as exc:
                failures += 1
                print(f"FAILED    {path}: {exc}")
    finally:
        ws.close()

    if args.keep_debug_port:
        print(f"\nleaving Vivaldi running with debug port {args.port} open")
    else:
        print("\nRestarting Vivaldi without the debug port...")
        quit_vivaldi()
        # graceful quit commits prefs to disk; confirm before relaunching
        prefs = read_preferences(args.profile_dir)
        for path in sorted(pending):
            if path not in pending_changes(values, prefs):
                continue
            failures += 1
            print(f"NOT PERSISTED  {path}")
        launch_vivaldi([])
    return 1 if failures else 0


def add_shared_options(parser: argparse.ArgumentParser, suppress_defaults: bool) -> None:
    # Defined on the top-level parser (real defaults) AND on each subparser
    # (SUPPRESS, so it doesn't clobber a value parsed at the top level) —
    # accepted both before and after the subcommand.
    def default(value):
        return argparse.SUPPRESS if suppress_defaults else value

    parser.add_argument(
        "--file",
        type=Path,
        default=default(DEFAULT_VALUES_PATH),
        help=f"managed values file (default: {DEFAULT_VALUES_PATH})",
    )
    parser.add_argument(
        "--profile",
        default=default("Default"),
        help='profile directory name under the Vivaldi user data dir, e.g. "Profile 1" (default: Default)',
    )
    parser.add_argument(
        "--profile-dir",
        type=Path,
        default=default(None),
        help="full profile directory path (overrides --profile)",
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    add_shared_options(parser, suppress_defaults=False)
    shared = argparse.ArgumentParser(add_help=False)
    add_shared_options(shared, suppress_defaults=True)
    sub = parser.add_subparsers(dest="command", required=True)

    p_dump = sub.add_parser(
        "dump", parents=[shared], help="capture current values of managed paths"
    )
    p_dump.add_argument("paths", nargs="*", help="pref paths to add, e.g. vivaldi.actions")
    p_dump.set_defaults(func=cmd_dump)

    p_diff = sub.add_parser("diff", parents=[shared], help="show managed paths that differ")
    p_diff.set_defaults(func=cmd_diff)

    p_ls = sub.add_parser(
        "ls", parents=[shared], help="explore pref paths in a profile's Preferences"
    )
    p_ls.add_argument(
        "path", nargs="?", default=None, help="pref path to list (default: top level)"
    )
    p_ls.set_defaults(func=cmd_ls)

    p_compare = sub.add_parser(
        "compare", parents=[shared], help="show pref differences between two profiles"
    )
    p_compare.add_argument("other", help='other profile name, e.g. "Profile 1"')
    p_compare.add_argument(
        "path", nargs="?", default="vivaldi", help="subtree to compare (default: vivaldi)"
    )
    p_compare.set_defaults(func=cmd_compare)

    p_apply = sub.add_parser(
        "apply", parents=[shared], help="write differing values via the prefs API"
    )
    p_apply.add_argument(
        "--port", type=int, default=DEFAULT_PORT, help=f"debug port (default: {DEFAULT_PORT})"
    )
    p_apply.add_argument(
        "--keep-debug-port",
        action="store_true",
        help="skip the final clean restart (leaves the debug port open)",
    )
    p_apply.set_defaults(func=cmd_apply)

    args = parser.parse_args()
    if args.profile_dir is None:
        args.profile_dir = VIVALDI_USER_DATA / args.profile
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
