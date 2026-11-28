#!/usr/bin/env python3
"""Open and close Herdr App spaces from Worktrunk's lifecycle hooks."""

import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def git_worktrees(repo):
    output = subprocess.check_output(
        ["git", "-C", repo, "worktree", "list", "--porcelain", "-z"], text=True
    )
    return [
        Path(record.split("\0", 1)[0].removeprefix("worktree ")).resolve()
        for record in output.split("\0\0")
        if record.startswith("worktree ")
    ]


def app_spaces():
    try:
        result = subprocess.run(
            ["herdr-app", "ls"], capture_output=True, text=True, timeout=10
        )
    except FileNotFoundError:
        return None
    if result.returncode:
        if result.stderr.startswith("herdr-app: no Herdr window at "):
            return None
        raise RuntimeError(result.stderr.strip() or "Could not list Herdr spaces.")
    return json.loads(result.stdout)["spaces"]


def space_command(command, **args):
    subprocess.run(
        ["herdr-app", "do", command, json.dumps(args)],
        stdout=subprocess.DEVNULL, check=True, timeout=10,
    )


def matching_spaces(spaces, checkout):
    return [
        space for space in spaces
        if not space["machine"] and space["folder"]
        and Path(space["folder"]).is_absolute()
        and Path(space["folder"]).resolve().is_relative_to(checkout)
    ]


@contextmanager
def space_lock():
    # Worktrunk runs each hook in its own process. Serialize the lookup and
    # app command so simultaneous switches cannot open duplicate spaces.
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    directory = cache / "motherbox"
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "herdr-worktrees.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def open_space(checkout):
    with space_lock():
        spaces = app_spaces()
        if spaces is None or not checkout.is_dir():
            return
        if checkout not in git_worktrees(checkout)[1:]:
            return
        existing = matching_spaces(spaces, checkout)
        if existing:
            space = next((space for space in existing if space["active"]), existing[0])
            space_command("space.select", id=space["id"])
        else:
            # Use Herdr's automatic name and let ya-spaces group by Git identity.
            space_command("space.new", folder=str(checkout), machine="")


def checkout_gone(repo, checkout):
    return not checkout.exists() and checkout not in git_worktrees(repo)


def close_space(repo, checkout):
    spaces = app_spaces()
    if spaces is None or not matching_spaces(spaces, checkout):
        return

    # Worktrunk can fall back to a detached Git removal on another filesystem.
    deadline = time.monotonic() + 20
    while not checkout_gone(repo, checkout):
        if time.monotonic() >= deadline:
            raise RuntimeError(f"Checkout still present at {checkout}.")
        time.sleep(0.2)

    with space_lock():
        spaces = app_spaces()
        if spaces is not None and checkout_gone(repo, checkout):
            for space in matching_spaces(spaces, checkout):
                space_command("space.close", id=space["id"], confirmed=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="operation", required=True)
    open_cmd = commands.add_parser("open", help="Open or focus a linked checkout after switching.")
    open_cmd.add_argument("checkout", type=Path)
    close_cmd = commands.add_parser("close", help="Close a linked checkout after removal.")
    close_cmd.add_argument("checkout", type=Path)
    close_cmd.add_argument(
        "--repo", type=Path, required=True, help="Primary checkout for the removed worktree."
    )
    args = parser.parse_args()

    try:
        checkout = args.checkout.resolve()
        if args.operation == "open":
            open_space(checkout)
        else:
            close_space(args.repo, checkout)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Herdr worktrees: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
