#!/usr/bin/env python3

import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys
from datetime import datetime


def check_dependencies():
    """Check that required commands are available."""
    required_commands = ["brew", "mas"]
    for cmd in required_commands:
        if not shutil.which(cmd):
            print(f"{cmd} command is required", file=sys.stderr)
            sys.exit(1)


def check_optional_command(cmd):
    """Check if an optional command is available."""
    return shutil.which(cmd) is not None


def run_command_safe(cmd):
    """Run a command and return its output, or None if the command fails or doesn't exist."""
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def get_repo_root():
    """Get the repository root directory."""
    return pathlib.Path(__file__).parent.parent.parent


def parse_brewfile(path: pathlib.Path):
    """Parse a Brewfile and extract formulas, casks, and vscode entries."""
    formulas = []
    casks = []
    vscode_extensions = []

    brew_pattern = re.compile(r'^brew\s+"([^"]+)"')
    cask_pattern = re.compile(r'^cask\s+"([^"]+)"')
    vscode_pattern = re.compile(r'^vscode\s+"([^"]+)"')

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

        m = vscode_pattern.match(line)
        if m:
            vscode_extensions.append(m.group(1).lower())
            continue

    return formulas, casks, vscode_extensions


def parse_mas_app_list(path: pathlib.Path):
    """Parse a mas app list file (apps/mas/*.txt) and return {name: app_id}."""
    entries = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # Format: APP_ID  # App Name
        parts = line.split("#", 1)
        if len(parts) == 2:
            app_id = parts[0].strip()
            name = parts[1].strip()
            if app_id:
                entries[name] = app_id
    return entries


def parse_tool_versions(path: pathlib.Path):
    """Parse a .tool-versions file and return a dict of plugin -> version."""
    tools = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        if len(parts) == 2:
            tools[parts[0]] = parts[1]
    return tools


def parse_default_npm_packages(path: pathlib.Path):
    """Parse .default-npm-packages and return a list of package names."""
    packages = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        packages.append(line)
    return packages


def run_command(cmd):
    """Run a command and return its output."""
    return subprocess.check_output(cmd, text=True)


def register_optional(path: pathlib.Path, optional_entries, optional_formulas, optional_casks):
    """Register optional Brewfile entries."""
    formulas, casks, _vscode = parse_brewfile(path)
    optional_entries[path.name] = {
        "formulas": formulas,
        "casks": casks,
    }
    optional_formulas.update(formulas)
    optional_casks.update(casks)


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
This script compares installed packages against declared manifests and generates a
markdown report at .tmp/APP_AUDIT.md covering:

  - Brew formulas and casks vs Brewfile, Mac App Store apps vs apps/mas/*.txt
  - NPM global packages vs .default-npm-packages
  - ASDF plugins and runtime versions vs .tool-versions
  - VSCode extensions vs apps/vscode/Brewfile
  - /Applications not managed by any tracked cask or MAS entry
  - Status of optional Brewfile entries (galileo.Brewfile, personal.Brewfile)

Required commands: brew, mas
Optional commands: npm, asdf, code
        """,
    )
    parser.parse_args()

    check_dependencies()

    repo_root = get_repo_root()
    tmp_dir = repo_root / ".tmp"
    tmp_dir.mkdir(exist_ok=True)
    audit_path = tmp_dir / "APP_AUDIT.md"
    core_brewfile = repo_root / "apps" / "brew" / "core.Brewfile"
    brewfile = repo_root / "apps" / "brew" / "Brewfile"
    optional_personal = repo_root / "apps" / "brew" / "personal.Brewfile"
    optional_work = repo_root / "apps" / "brew" / "galileo.Brewfile"

    if not brewfile.exists():
        raise SystemExit(f"Missing Brewfile at {brewfile}")

    # Manifest paths for non-brew audits
    vscode_brewfile = repo_root / "apps" / "vscode" / "Brewfile"
    tool_versions_file = repo_root / "apps" / "asdf" / ".tool-versions"
    default_npm_file = repo_root / "apps" / "asdf" / ".default-npm-packages"

    # Parse core + main Brewfile
    brew_formulas_declared, brew_casks_declared, _ = parse_brewfile(brewfile)
    if core_brewfile.exists():
        core_formulas, _, _ = parse_brewfile(core_brewfile)
        brew_formulas_declared.extend(core_formulas)

    # Parse mas app lists from apps/mas/
    mas_dir = repo_root / "apps" / "mas"
    mas_declared = {}
    for mas_file in sorted(mas_dir.glob("*.txt")):
        mas_declared.update(parse_mas_app_list(mas_file))

    # Handle optional Brewfiles
    optional_entries = {}
    optional_formulas = set()
    optional_casks = set()

    if optional_personal.exists():
        register_optional(optional_personal, optional_entries, optional_formulas, optional_casks)
    if optional_work.exists():
        register_optional(optional_work, optional_entries, optional_formulas, optional_casks)

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

    mas_not_tracked = sorted(mas_installed_set - mas_declared_set)
    mas_missing = sorted(mas_declared_set - mas_installed_set)

    # --- NPM global packages ---
    npm_declared = []
    if default_npm_file.exists():
        npm_declared = parse_default_npm_packages(default_npm_file)
    npm_declared_set = set(npm_declared)

    npm_installed_set = set()
    if check_optional_command("npm"):
        npm_raw = run_command_safe(["npm", "list", "-g", "--depth=0", "--json"])
        if npm_raw:
            try:
                data = json.loads(npm_raw)
                npm_installed_set = set(data.get("dependencies", {}).keys())
                npm_installed_set.discard("npm")
            except json.JSONDecodeError:
                pass

    npm_not_tracked = sorted(npm_installed_set - npm_declared_set)
    npm_missing = sorted(npm_declared_set - npm_installed_set)

    # --- ASDF plugins & runtimes ---
    asdf_declared = {}
    if tool_versions_file.exists():
        asdf_declared = parse_tool_versions(tool_versions_file)
    asdf_declared_plugins = set(asdf_declared.keys())

    asdf_installed_plugins = set()
    asdf_version_status = {}
    if check_optional_command("asdf"):
        plugins_raw = run_command_safe(["asdf", "plugin", "list"])
        if plugins_raw:
            asdf_installed_plugins = set(plugins_raw.split())

        # Check version status for declared runtimes
        for plugin, version in asdf_declared.items():
            if plugin not in asdf_installed_plugins:
                asdf_version_status[plugin] = "plugin not installed"
            else:
                current_raw = run_command_safe(["asdf", "current", "--no-header", plugin])
                if current_raw:
                    parts = current_raw.split()
                    # Format: name version source installed
                    if len(parts) >= 2 and parts[1] == version:
                        asdf_version_status[plugin] = "installed"
                    else:
                        asdf_version_status[plugin] = f"wrong version ({parts[1] if len(parts) >= 2 else '?'})"
                else:
                    asdf_version_status[plugin] = "not installed"

    asdf_plugins_not_tracked = sorted(asdf_installed_plugins - asdf_declared_plugins)
    asdf_plugins_missing = sorted(asdf_declared_plugins - asdf_installed_plugins)

    # --- VSCode extensions ---
    vscode_declared = []
    if vscode_brewfile.exists():
        _, _, _, vscode_declared = parse_brewfile(vscode_brewfile)
    vscode_declared_set = set(vscode_declared)

    vscode_installed_set = set()
    if check_optional_command("code"):
        vscode_raw = run_command_safe(["code", "--list-extensions"])
        if vscode_raw:
            vscode_installed_set = {ext.strip().lower() for ext in vscode_raw.splitlines() if ext.strip()}

    vscode_not_tracked = sorted(vscode_installed_set - vscode_declared_set)
    vscode_missing = sorted(vscode_declared_set - vscode_installed_set)

    # --- /Applications audit ---
    applications_dir = pathlib.Path("/Applications")
    app_names_on_disk = set()
    if applications_dir.exists():
        for entry in applications_dir.iterdir():
            if entry.suffix == ".app":
                app_names_on_disk.add(entry.stem)

    # Build a set of app names that brew casks and mas would have installed
    # Cask names use hyphens, app names use spaces/caps — normalize for matching
    known_managed_apps = set()
    # Add all cask names (declared + installed) normalized
    for name in casks_declared_set | casks_installed_set:
        known_managed_apps.add(name.lower().replace("-", " ").replace("@", " "))
    # Add all mas app names
    for name in mas_declared_set | mas_installed_set:
        known_managed_apps.add(name.lower())

    unmanaged_apps = []
    for app_name in sorted(app_names_on_disk):
        normalized = app_name.lower().replace("-", " ")
        # Check if any known managed name is a substring match (handles "Google Chrome" vs "google-chrome")
        if not any(managed in normalized or normalized in managed for managed in known_managed_apps):
            unmanaged_apps.append(app_name)

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
    lines.append("### Installed apps not tracked (add to apps/mas/*.txt or uninstall manually)")
    lines.extend(format_items(mas_not_tracked, lambda name: f"{name} (id: {mas_installed[name]})"))
    lines.append("")
    lines.append("### Apps declared but not installed")
    lines.extend(format_items(mas_missing, lambda name: f"{name} (id: {mas_declared[name]})"))
    lines.append("")
    lines.append("_Note: Use `sudo mas uninstall <app_id>` to remove Mac App Store apps._")
    lines.append("")

    # NPM global packages
    lines.append("## NPM Global Packages")
    lines.append("")
    lines.append("Managed manifest: `apps/asdf/.default-npm-packages`")
    lines.append("")
    lines.append("### Installed global packages not tracked")
    lines.extend(format_items(npm_not_tracked, lambda name: name))
    lines.append("")
    lines.append("### Packages declared but not installed")
    lines.extend(format_items(npm_missing, lambda name: name))
    lines.append("")

    # ASDF plugins & runtimes
    lines.append("## ASDF Plugins & Runtimes")
    lines.append("")
    lines.append("Managed manifest: `apps/asdf/.tool-versions`")
    lines.append("")
    lines.append("### Installed plugins not tracked")
    lines.extend(format_items(asdf_plugins_not_tracked, lambda name: name))
    lines.append("")
    lines.append("### Plugins declared but not installed")
    lines.extend(format_items(asdf_plugins_missing, lambda name: name))
    lines.append("")
    if asdf_version_status:
        lines.append("### Runtime version status")
        for plugin in sorted(asdf_version_status):
            status = asdf_version_status[plugin]
            declared_ver = asdf_declared.get(plugin, "?")
            check = "x" if status == "installed" else " "
            lines.append(f"- [{check}] {plugin} {declared_ver} — {status}")
        lines.append("")

    # VSCode extensions
    lines.append("## VSCode Extensions")
    lines.append("")
    lines.append("Managed manifest: `apps/vscode/Brewfile`")
    lines.append("")
    lines.append("### Installed extensions not tracked")
    lines.extend(format_items(vscode_not_tracked, lambda name: name))
    lines.append("")
    lines.append("### Extensions declared but not installed")
    lines.extend(format_items(vscode_missing, lambda name: name))
    lines.append("")

    # /Applications audit
    lines.append("## Unmanaged Applications")
    lines.append("")
    lines.append("_Apps in /Applications not matched to any brew cask or Mac App Store entry._")
    lines.append("")
    lines.extend(format_items(unmanaged_apps, lambda name: name))
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
            if not found:
                lines.append("- No entries defined")
            lines.append("")

    # Write output
    with audit_path.open("w", encoding="utf-8") as fh:
        fh.write("\n".join(lines).rstrip() + "\n")

    print(f"App audit written to {audit_path}")


if __name__ == "__main__":
    main()
