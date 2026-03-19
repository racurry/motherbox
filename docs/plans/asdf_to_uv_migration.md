# Migration Plan: asdf to uv for Python

Replace asdf with uv for Python version and package management while keeping asdf for Ruby and Node.js.

______________________________________________________________________

## Recommendation: Wait

> **Last reviewed**: 2025-12-01

**TL;DR**: Don't migrate yet. The practical day-to-day benefits are minimal. You can get 90% of uv's benefits without changing Python version management.

### Why wait?

| Factor                    | Assessment                                                  |
| ------------------------- | ----------------------------------------------------------- |
| Speed of package installs | Already available via `uv pip` - no migration needed        |
| Speed of Python installs  | Marginal; you install Python ~2-3x/year                     |
| Unified tooling           | Still need asdf for Ruby/Node.js anyway                     |
| Risk                      | Real cost (time, breakage) for mostly philosophical benefit |

### Do this instead

Add to `.zshrc`:

```bash
alias pip='uv pip'
alias pip3='uv pip'
```

This gives you fast package operations while keeping asdf for Python versions.

### Revisit when

- uv's Python version management matures further
- direnv gains native uv support
- You're ready to eliminate asdf entirely (consider mise)
- You're joining a team that standardizes on uv

### If you decide to proceed anyway

The rest of this document provides a complete migration plan. The plan is solid; the question is whether the juice is worth the squeeze.

______________________________________________________________________

## Executive Summary

| Aspect              | Current (asdf)       | Target (uv)                 |
| ------------------- | -------------------- | --------------------------- |
| Python version file | `.tool-versions`     | `.python-version`           |
| Version source      | asdf-python plugin   | python-build-standalone     |
| Package install     | `pip install`        | `uv pip install` / `uv add` |
| Virtualenv          | `python -m venv`     | `uv venv` (automatic)       |
| Global tools        | `pip install --user` | `uv tool install` / `uvx`   |
| Script deps         | requirements.txt     | PEP 723 inline metadata     |
| direnv hook         | `use asdf`           | `use uv` (custom)           |

**Key advantage**: uv is 10-100x faster than pip and handles Python installation, venv creation, and package management as a single unified tool.

______________________________________________________________________

## Key Concept: No Shims

Unlike asdf, uv does **not** use shims. This has important implications:

| Aspect             | asdf                                          | uv                             |
| ------------------ | --------------------------------------------- | ------------------------------ |
| How `python` works | Shim intercepts, redirects to correct version | Real executable (or not found) |
| PATH requirement   | asdf shims dir on PATH                        | `~/.local/bin` on PATH         |
| Version switching  | Automatic per-directory via `.tool-versions`  | Manual or via direnv           |

**After migration**, running `python` directly uses whatever is first on PATH. To make uv-managed Python the default:

```bash
# Add to .zshrc
export PATH="$HOME/.local/bin:$PATH"

# Then install with --default flag
uv python install 3.12 --default
```

This installs `python`, `python3`, and `python3.12` executables to `~/.local/bin`.

______________________________________________________________________

## Phase 1: Preparation

### 1.1 Create `apps/uv/` Directory

```
apps/uv/
├── uv.sh              # Setup script
├── uv.toml            # Global uv config (optional)
├── use_uv.sh          # direnv library
├── .python-version    # Global Python version spec
├── README.md
└── test_uv.bats
```

### 1.2 Verify uv Installation

uv is already in `apps/brew/Brewfile`. Confirm it's present:

```bash
brew list | grep uv
```

### 1.3 Document Current Python Usage

Before migrating, audit where Python is used:

| Location                                  | Purpose               | Migration Impact                |
| ----------------------------------------- | --------------------- | ------------------------------- |
| `apps/asdf/.tool-versions`                | Global Python 3.12.5  | Move to `.python-version`       |
| `apps/asdf/.default-python-packages`      | Auto-install packages | Replace with uv tools           |
| `scripts/splitpdf`                        | Utility script        | Already uses uv!                |
| `apps/openscad/update_vscode_settings.py` | Config updater        | Add inline deps or keep minimal |
| `apps/brew/audit_apps.py`                 | Brew audit            | Stdlib only, no changes         |

______________________________________________________________________

## Phase 2: Create uv App

### 2.1 `apps/uv/uv.sh`

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="uv"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Manage uv Python version and package management.

Commands:
    setup       Run full setup (install Python, configure)
    help        Show this help message
EOF
}

link_config_files() {
    print_heading "Link uv config files"

    # Global Python version
    link_home_dotfile "${SCRIPT_DIR}/.python-version" "${APP_NAME}"

    # Optional: Global uv.toml
    ensure_xdg_dir uv
    link_xdg_config "${SCRIPT_DIR}/uv.toml" "uv" "${APP_NAME}"
}

install_python() {
    print_heading "Install Python via uv"

    require_command uv

    # Read version from .python-version
    local version
    version=$(cat "${SCRIPT_DIR}/.python-version")

    log_info "Installing Python ${version}"
    uv python install "${version}"
}

setup_direnv_lib() {
    print_heading "Setup direnv uv integration"

    local direnv_lib_dir="${HOME}/.config/direnv/lib"
    mkdir -p "${direnv_lib_dir}"

    ln -sf "${SCRIPT_DIR}/use_uv.sh" "${direnv_lib_dir}/use_uv.sh"
    log_info "Linked use_uv.sh to direnv lib"
}

do_setup() {
    link_config_files
    install_python
    setup_direnv_lib
}

main() {
    case "${1:-}" in
        setup) do_setup ;;
        help|--help|-h|"") show_help ;;
        *) log_warn "Unknown: $1"; show_help; exit 1 ;;
    esac
}

main "$@"
```

### 2.2 `apps/uv/.python-version`

```
3.12.5
```

### 2.3 `apps/uv/uv.toml` (Optional Global Config)

```toml
# Global uv settings
# See: https://docs.astral.sh/uv/reference/settings/

# Prefer uv-managed Python installations
python-preference = "managed"

# Automatically download Python if needed
python-downloads = "automatic"
```

### 2.4 `apps/uv/use_uv.sh` (direnv integration)

```bash
# ~/.config/direnv/lib/use_uv.sh
# Usage in .envrc: use uv

use_uv() {
    # Watch relevant files for changes
    watch_file .python-version
    watch_file pyproject.toml
    watch_file uv.lock
    watch_file requirements.txt

    # Create venv if it doesn't exist
    if [[ ! -d .venv ]]; then
        log_status "Creating virtualenv with uv"
        uv venv
    fi

    # Activate the venv
    source .venv/bin/activate

    # Sync dependencies if lockfile exists
    if [[ -f uv.lock ]]; then
        log_status "Syncing dependencies (uv.lock)"
        uv sync --frozen 2>/dev/null || uv sync
    elif [[ -f pyproject.toml ]]; then
        log_status "Syncing dependencies (pyproject.toml)"
        uv sync 2>/dev/null || true
    elif [[ -f requirements.txt ]]; then
        log_status "Installing requirements.txt"
        uv pip sync requirements.txt 2>/dev/null || uv pip install -r requirements.txt
    fi
}
```

______________________________________________________________________

## Phase 3: Update asdf Configuration

### 3.1 Modify `apps/asdf/.tool-versions`

Remove Python, keep Ruby and Node.js:

```diff
- python 3.12.5
  ruby 3.4.4
  nodejs 24.1.0
```

### 3.2 Remove Python-specific Files

Delete or archive:

- `apps/asdf/.default-python-packages` (no longer needed)

### 3.3 Update `apps/asdf/asdf.sh`

Remove Python-specific environment variable handling:

```diff
  install_runtimes() {
      print_heading "Install asdf runtimes"
      require_command asdf
      log_info "Running 'asdf install'"
-     unset ASDF_RUBY_VERSION ASDF_NODEJS_VERSION ASDF_PYTHON_VERSION
+     unset ASDF_RUBY_VERSION ASDF_NODEJS_VERSION
      asdf install
  }
```

______________________________________________________________________

## Phase 4: Update Shell Configuration

### 4.1 Modify `apps/zsh/.zshrc`

Add PATH and muscle-memory aliases:

```bash
# After Homebrew setup, before asdf
export PATH="$HOME/.local/bin:$PATH"  # uv Python and tools

# Redirect pip muscle memory to uv
alias pip='uv pip'
alias pip3='uv pip'
```

**Why the aliases?** If you're used to typing `pip install`, this redirects to `uv pip install` automatically. Key differences:

| Command                        | Behavior                                                       |
| ------------------------------ | -------------------------------------------------------------- |
| `uv add foo`                   | Adds to `pyproject.toml` and installs (preferred for projects) |
| `uv pip install foo`           | Installs to venv only, doesn't update pyproject.toml           |
| `pip install foo` (with alias) | Same as `uv pip install foo`                                   |

The alias prevents accidents but doesn't change project files. For tracked dependencies, use `uv add`.

### 4.2 Update direnv Integration

Modify `apps/direnv/direnv.sh` to also link `use_uv.sh`:

```bash
setup_direnv_lib() {
    local direnv_lib_dir="${HOME}/.config/direnv/lib"
    mkdir -p "${direnv_lib_dir}"

    ln -sf "${SCRIPT_DIR}/use_asdf.sh" "${direnv_lib_dir}/use_asdf.sh"
    # Link uv library if apps/uv exists
    if [[ -f "${SCRIPT_DIR}/../uv/use_uv.sh" ]]; then
        ln -sf "${SCRIPT_DIR}/../uv/use_uv.sh" "${direnv_lib_dir}/use_uv.sh"
    fi
}
```

Alternatively, have `apps/uv/uv.sh` handle its own direnv setup (shown in Phase 2).

______________________________________________________________________

## Phase 5: Update Agent Rules

### 5.1 Modify `apps/claudecode/AGENTS.global.md`

```diff
  # Rules for Coding Agents

- - **Runtime management**: Use `asdf` for runtime version management (never install runtimes via apt/brew/etc).  If asdf is not installed, ask for guidance.
+ - **Runtime management**: Use `uv` for Python version management and `asdf` for Ruby/Node.js. Never install runtimes via apt/brew/etc.
  - **Project environment**: Use `direnv` to manage project environments (venvs, PATH, env vars, etc.). Create `.envrc` if needed. If direnv is not installed, ask for guidance.
- - **Package management**: For asdf-managed runtimes (node/python/ruby/etc), install packages locally to the project; never install globally
+ - **Package management**: Use `uv` for Python packages. For node/ruby, install packages locally to the project; never install globally.

  ## Python rules

- - **Virtual environments**: Use `venv` for virtual environments. Configure `.envrc` with `layout python` to integrate with direnv.
- - **Package management**: Use `uv` for package management, unless the project already uses other tools (poetry, pipenv, conda, etc.). Check for existing configuration files (pyproject.toml, Pipfile, environment.yml) before making assumptions.
+ - **Virtual environments**: Use `uv venv` for virtual environments. Configure `.envrc` with `use uv` to integrate with direnv.
+ - **Package management**: Use `uv` for all Python package management. Prefer `pyproject.toml` for project dependencies. For standalone scripts, use PEP 723 inline metadata (see `scripts/splitpdf` for example). Only fall back to other tools (poetry, pipenv, conda) if the project already uses them.
+ - **Running tools**: Use `uvx` to run Python CLI tools without installing them globally.
```

______________________________________________________________________

## Phase 6: Update Setup Orchestration

### 6.1 Modify `run/setup.sh`

Add uv setup after brew, before asdf:

```diff
  print_heading "Dev Tools"
+ run_app_setup uv    # Python version management
  run_app_setup asdf  # Ruby/Node.js version management
  run_app_setup git
  run_app_setup direnv
```

**Order rationale**: uv comes before asdf because Python is more commonly needed immediately. asdf now only handles Ruby and Node.js.

______________________________________________________________________

## Phase 7: Migration Execution

### 7.1 Pre-Migration Checklist

- [ ] Backup current `.tool-versions`: `cp ~/.tool-versions ~/.tool-versions.bak`
- [ ] Note any globally installed Python packages: `pip list --user`
- [ ] Identify projects with `.envrc` files using `use asdf`

### 7.2 Execution Steps

```bash
# 1. Create the apps/uv directory and files (as described above)

# 2. Run uv setup
./apps/uv/uv.sh setup

# 3. Verify Python is available via uv
uv python list
which python  # Should show uv-managed path

# 4. Update asdf config (remove Python)
# Edit apps/asdf/.tool-versions manually

# 5. Reinstall asdf runtimes (Ruby/Node only now)
./apps/asdf/asdf.sh setup

# 6. Update direnv
./apps/direnv/direnv.sh setup

# 7. Reload shell
source ~/.zshrc
```

### 7.3 Project Migration

For each project using Python with asdf:

```bash
cd /path/to/project

# Create .python-version if needed
echo "3.12" > .python-version

# Update .envrc
# Old: use asdf
# New: use uv

# Or for mixed projects (Ruby + Python):
# use asdf
# use uv

# Allow the new .envrc
direnv allow

# If project has requirements.txt, convert to pyproject.toml (optional)
uv init  # Creates pyproject.toml
uv add $(cat requirements.txt | grep -v '^#' | grep -v '^$')
```

______________________________________________________________________

## Phase 8: Verification

### 8.1 System Checks

```bash
# Python managed by uv
uv python list
python --version

# Ruby/Node still managed by asdf
asdf current ruby
asdf current nodejs

# Tools work
uvx ruff check .
```

### 8.2 Run Tests

```bash
./run/test.sh
```

### 8.3 Test Project Workflows

```bash
# Test a Python project
cd ~/workspace/some-python-project
direnv allow
python --version  # Should match .python-version
uv pip list       # Should show project deps
```

______________________________________________________________________

## Rollback Plan

If issues arise:

```bash
# Restore asdf Python
echo "python 3.12.5" >> ~/.tool-versions
asdf plugin add python
asdf install python 3.12.5

# Restore old .envrc files
# Change "use uv" back to "use asdf"
```

______________________________________________________________________

## Decision Points

### Q1: Keep asdf at all?

**Recommendation**: Yes, for Ruby and Node.js. uv only handles Python.

If you eventually want to eliminate asdf entirely:

- Node.js: Consider `fnm` or `volta`
- Ruby: Consider `rbenv` or `mise`
- Or wait for `mise` to mature as a unified replacement

### Q2: Global Python tools?

**Recommendation**: Use `uvx` for one-off runs, `uv tool install` for persistent tools.

```bash
# One-off
uvx black myfile.py

# Persistent (adds to ~/.local/bin)
uv tool install ruff
uv tool install black
```

### Q3: What about ruff.toml?

**No change needed**. Ruff configuration is independent of Python version management.

______________________________________________________________________

## Working with Legacy pip Projects

You can use uv as your system Python manager while still working on projects that use traditional pip workflows.

### Option 1: Use `uv pip` directly (recommended)

For projects with `requirements.txt` and no `pyproject.toml`:

```bash
cd legacy-project/
uv venv                              # create venv
source .venv/bin/activate
uv pip install -r requirements.txt   # works like pip
uv pip install some-package          # ad-hoc installs
uv pip freeze > requirements.txt     # update requirements
```

No project changes needed. The `uv pip` interface is 99% compatible with pip.

### Option 2: Shell aliases (covers muscle memory)

With the aliases from Phase 4:

```bash
alias pip='uv pip'
```

Your muscle memory (`pip install foo`) automatically uses uv's faster implementation.

**Limitation**: Aliases only work in interactive shells. Scripts calling `pip` directly won't use the alias.

### Option 3: pip-uv shim (for stubborn scripts)

If a legacy project has Makefiles or scripts that call `pip` directly:

```bash
uv pip install pip-uv
```

This installs a shim that intercepts `pip` commands in the venv:

| Context       | `pip install foo` becomes |
| ------------- | ------------------------- |
| Has `uv.lock` | `uv add foo`              |
| No `uv.lock`  | `uv pip install foo`      |

**When to use**: Only if you can't/won't edit scripts that invoke `pip`. Otherwise, aliases or direct `uv pip` usage is simpler.

### Compatibility notes

uv's pip interface differs from pip in some edge cases:

- Resolution strategy may produce different (but valid) dependency versions
- Pre-releases require explicit opt-in
- Multiple indexes use first-match (security feature)

For typical projects, these differences rarely matter.

______________________________________________________________________

## Files Changed Summary

| File                                 | Action                         |
| ------------------------------------ | ------------------------------ |
| `apps/uv/` (new directory)           | Create                         |
| `apps/uv/uv.sh`                      | Create                         |
| `apps/uv/.python-version`            | Create                         |
| `apps/uv/uv.toml`                    | Create (optional)              |
| `apps/uv/use_uv.sh`                  | Create                         |
| `apps/uv/README.md`                  | Create                         |
| `apps/asdf/.tool-versions`           | Remove `python` line           |
| `apps/asdf/.default-python-packages` | Delete                         |
| `apps/asdf/asdf.sh`                  | Remove Python env var handling |
| `apps/zsh/.zshrc`                    | Add PATH and pip aliases       |
| `apps/claudecode/AGENTS.global.md`   | Update rules                   |
| `run/setup.sh`                       | Add `run_app_setup uv`         |
| `apps/direnv/README.md`              | Add uv usage docs              |

______________________________________________________________________

## References

- [uv Documentation](https://docs.astral.sh/uv/)
- [uv Python Version Management](https://docs.astral.sh/uv/concepts/python-versions/)
- [uv pip Compatibility](https://docs.astral.sh/uv/pip/compatibility/)
- [pip-uv shim](https://github.com/guysoft/pip-uv) - Redirects `pip` to `uv pip`
- [uv + direnv Integration](https://offby1.website/posts/uv-direnv-and-simple-envrc-files.html)
- [Switching to direnv and uv](https://treyhunner.com/2024/10/switching-from-virtualenvwrapper-to-direnv-starship-and-uv/)
- [direnv uv support discussion](https://github.com/direnv/direnv/issues/1250)
