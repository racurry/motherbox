#!/usr/bin/env python3

import sys
import subprocess
import pathlib
import re
import shutil
import argparse
from datetime import datetime


def check_dependencies():
    """Check that required commands are available."""
    required_commands = ["brew", "mas"]
    for cmd in required_commands:
        if not shutil.which(cmd):
            print(f"{cmd} command is required", file=sys.stderr)
            sys.exit(1)


def get_repo_root():
    """Get the repository root directory."""
    return pathlib.Path(__file__).parent.parent.parent


def parse_brewfile(path: pathlib.Path):
    """Parse a Brewfile and extract formulas, casks, and mas entries."""
    formulas = []
    casks = []
    mas_entries = {}

    brew_pattern = re.compile(r'^brew\s+"([^"]+)"')
    cask_pattern = re.compile(r'^cask\s+"([^"]+)"')
    mas_pattern = re.compile(r'^mas\s+"([^"]+)",\s*id:\s*(\d+)')

    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        m = brew_pattern.match(line)
        if m:
            formulas.append(m.group(1))
            continue

        m = cask_pattern.match(line)
        if m:
            casks.append(m.group(1))
            continue

        m = mas_pattern.match(line)
        if m:
            name, app_id = m.groups()
            mas_entries[name] = app_id
            continue

    return formulas, casks, mas_entries


def run_command(cmd):
    """Run a command and return its output."""
    return subprocess.check_output(cmd, text=True)


def register_optional(path: pathlib.Path, optional_entries, optional_formulas, optional_casks, optional_mas):
    """Register optional Brewfile entries."""
    formulas, casks, mas_entries = parse_brewfile(path)
    optional_entries[path.name] = {
        "formulas": formulas,
        "casks": casks,
        "mas": mas_entries,
    }
    optional_formulas.update(formulas)
    optional_casks.update(casks)
    optional_mas.update(mas_entries.keys())


def format_items(items, formatter):
    """Format a list of items as markdown checklist."""
    if not items:
        return ["- [x] None"]
    return [f"- [ ] {formatter(item)}" for item in items]


def main():
    parser = argparse.ArgumentParser(
        description="Audit installed applications against Brewfile manifests.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This script compares installed packages (brew formulas, casks, and Mac App Store apps)
against the declared packages in Brewfile manifests. It generates a markdown report at
.tmp/APP_AUDIT.md with the following information:

  - Installed packages not tracked in any Brewfile (consider adding or uninstalling)
  - Declared packages not installed (install or remove from Brewfile)
  - Status of optional Brewfile entries (galileo.Brewfile, personal.Brewfile)

Required commands: brew, mas
        """,
    )
    parser.parse_args()

    check_dependencies()

    repo_root = get_repo_root()
    tmp_dir = repo_root / ".tmp"
    tmp_dir.mkdir(exist_ok=True)
    audit_path = tmp_dir / "APP_AUDIT.md"
    brewfile = repo_root / "apps" / "brew" / "Brewfile"
    optional_personal = repo_root / "apps" / "brew" / "personal.Brewfile"
    optional_work = repo_root / "apps" / "brew" / "galileo.Brewfile"

    if not brewfile.exists():
        raise SystemExit(f"Missing Brewfile at {brewfile}")

    # Parse main Brewfile
    brew_formulas_declared, brew_casks_declared, mas_declared = parse_brewfile(brewfile)

    # Handle optional Brewfiles
    optional_entries = {}
    optional_formulas = set()
    optional_casks = set()
    optional_mas = set()

    if optional_personal.exists():
        register_optional(optional_personal, optional_entries, optional_formulas, optional_casks, optional_mas)
    if optional_work.exists():
        register_optional(optional_work, optional_entries, optional_formulas, optional_casks, optional_mas)

    # Get installed packages
    brew_formulas_installed = run_command(["brew", "list", "--formula"]).split()
    brew_casks_installed = run_command(["brew", "list", "--cask"]).split()
    brew_leaves = run_command(["brew", "leaves"]).split()

    # Parse mas output
    mas_raw = run_command(["mas", "list"]).splitlines()
    mas_installed = {}
    for line in mas_raw:
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        app_id, rest = parts
        name = rest.rsplit("(", 1)[0].rstrip()
        mas_installed[name] = app_id

    # Convert to sets for comparison
    formulas_declared_set = set(brew_formulas_declared)
    formulas_leaves_set = set(brew_leaves)
    formulas_installed_set = set(brew_formulas_installed)

    casks_declared_set = set(brew_casks_declared)
    casks_installed_set = set(brew_casks_installed)

    mas_declared_set = set(mas_declared.keys())
    mas_installed_set = set(mas_installed.keys())

    # Calculate differences
    formulas_not_tracked = sorted(formulas_leaves_set - formulas_declared_set - optional_formulas)
    formulas_missing = sorted(formulas_declared_set - formulas_installed_set)

    casks_not_tracked = sorted(casks_installed_set - casks_declared_set - optional_casks)
    casks_missing = sorted(casks_declared_set - casks_installed_set)

    mas_not_tracked = sorted(mas_installed_set - mas_declared_set - optional_mas)
    mas_missing = sorted(mas_declared_set - mas_installed_set)

    # Generate report
    lines = []
    lines.append("# App Audit")
    lines.append("")
    lines.append(f"_Generated on {datetime.now().isoformat(timespec='seconds')}_")
    lines.append("")
    lines.append("Managed manifest: `apps/brew/Brewfile`")
    lines.append("")
    lines.append("## Brew Apps")
    lines.append("")
    lines.append("### Installed brew leaves not tracked (consider adding or uninstalling)")
    lines.extend(format_items(formulas_not_tracked, lambda name: name))
    lines.append("")
    lines.append("### Formulas declared but not installed (install or prune from Brewfile)")
    lines.extend(format_items(formulas_missing, lambda name: name))
    lines.append("")
    lines.append("## Homebrew Casks")
    lines.append("")
    lines.append("### Installed casks not tracked")
    lines.extend(format_items(casks_not_tracked, lambda name: name))
    lines.append("")
    lines.append("### Casks declared but not installed")
    lines.extend(format_items(casks_missing, lambda name: name))
    lines.append("")
    lines.append("## Mac App Store Apps")
    lines.append("")
    lines.append("### Installed apps not tracked (add to Brewfile or uninstall manually)")
    lines.extend(format_items(mas_not_tracked, lambda name: f"{name} (id: {mas_installed[name]})"))
    lines.append("")
    lines.append("### Apps declared but not installed")
    lines.extend(format_items(mas_missing, lambda name: f"{name} (id: {mas_declared[name]})"))
    lines.append("")
    lines.append("_Note: Use `sudo mas uninstall <app_id>` to remove Mac App Store apps._")
    lines.append("")

    # Optional Brewfiles section
    if optional_entries:
        lines.append("## Optional Brewfiles")
        lines.append("")
        for filename, payload in optional_entries.items():
            lines.append(f"### {filename}")
            found = False
            for name in payload["formulas"]:
                status = "installed" if name in formulas_installed_set else "missing"
                lines.append(f"- brew {name} — {status}")
                found = True
            for name in payload["casks"]:
                status = "installed" if name in casks_installed_set else "missing"
                lines.append(f"- cask {name} — {status}")
                found = True
            for name, app_id in payload["mas"].items():
                status = "installed" if name in mas_installed else "missing"
                lines.append(f"- mas {name} (id: {app_id}) — {status}")
                found = True
            if not found:
                lines.append("- No entries defined")
            lines.append("")

    # Write output
    with audit_path.open("w", encoding="utf-8") as fh:
        fh.write("\n".join(lines).rstrip() + "\n")

    print(f"App audit written to {audit_path}")


if __name__ == "__main__":
    main()
