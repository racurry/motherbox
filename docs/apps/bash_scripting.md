# Bash Scripting

App scripts written in bash follow this template:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

APP_NAME="appname"  # Used for backup organization

show_help() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Short description of what this script does.

Commands:
    setup       Run full setup (install app, then configure)
    install     Install the app if not already installed
    help        Show this help message (also: -h, --help)

Options:
    --flag      Description of the flag
EOF
}

do_install() {
    print_heading "Installing ${APP_NAME}"

    # Skip if already installed (adjust check as needed)
    if command -v appname >/dev/null 2>&1; then
        log_info "${APP_NAME} already installed"
        return 0
    fi

    # Install via brew (adjust formula/cask as needed)
    require_command brew
    brew install --cask appname
    log_success "${APP_NAME} installed"
}

do_setup() {
    do_install

    print_heading "Configuring ${APP_NAME}"
    # Configuration logic here
    log_info "Setup complete"
}

main() {
    local command=""
    local args=("$@")

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --flag)
                # handle flag
                shift
                ;;
            help|--help|-h)
                show_help
                exit 0
                ;;
            setup|install)
                command="$1"
                shift
                ;;
            *)
                # Check if it's a global flag from run/setup.sh
                if shift_count=$(check_global_flag "$@"); then
                    shift "$shift_count"
                else
                    log_warn "Ignoring unknown argument: $1"
                    shift
                fi
                ;;
        esac
    done

    case "${command}" in
        setup)
            do_setup
            ;;
        install)
            do_install
            ;;
        "")
            show_help
            exit 0
            ;;
    esac
}

main "$@"
```

## Conventions

| Convention                            | Example                                    |
| ------------------------------------- | ------------------------------------------ |
| Use `setup` as main entry point       | `./apps/myapp/myapp.sh setup`              |
| `setup` calls `install` first         | `do_setup()` begins with `do_install`      |
| `install` is idempotent               | Check if installed before installing       |
| Accept `help`, `-h`, `--help`         | All three should work                      |
| Use `fail` for errors                 | `fail "Missing config file"`               |
| Use `$REPO_ROOT` for paths            | `${REPO_ROOT}/apps/myapp/config`           |
| Use `--flag value` not `--flag=value` | `--profile personal`                       |
| Use `check_global_flag()` in default  | Silently consume global flags              |
| Warn on unknown args, don't fail      | `log_warn "Ignoring unknown argument: $1"` |

## Available Functions (from `common.sh`)

| Function                      | Purpose                                         |
| ----------------------------- | ----------------------------------------------- |
| `print_heading "text"`        | Section headers                                 |
| `log_info "text"`             | Info messages                                   |
| `log_warn "text"`             | Warnings                                        |
| `log_success "text"`          | Success messages                                |
| `fail "text"`                 | Error and exit                                  |
| `require_command cmd`         | Guard: command exists                           |
| `require_file path`           | Guard: file exists                              |
| `require_directory path`      | Guard: directory exists                         |
| `link_file src dest app_name` | Symlink config (backs up existing)              |
| `copy_file src dest app_name` | Copy config (backs up existing)                 |
| `check_global_flag "$@"`      | Check if arg is global flag, return shift count |

See [copying_configs.md](copying_configs.md) for details on `link_file` vs `copy_file`.

## Global Flag Handling

Scripts are called by `run/setup.sh` with global flags like `--profile`, `--unattended`, `--debug`, and `--logging`. Use `check_global_flag()` in the default case to consume these silently:

```bash
*)
    # Check if it's a global flag from run/setup.sh
    if shift_count=$(check_global_flag "$@"); then
        shift "$shift_count"
    else
        log_warn "Ignoring unknown argument: $1"
        shift
    fi
    ;;
```

This prevents noise from known pass-through flags while still warning about truly unknown arguments. The function handles both boolean flags (`--unattended`) and value flags (`--profile galileo`) correctly.

## Path Variables (from `common.sh`)

| Variable                      | Value                         |
| ----------------------------- | ----------------------------- |
| `$REPO_ROOT`                  | Repository root path          |
| `$PATH_MOTHERBOX_CONFIG`      | `~/.config/motherbox`         |
| `$PATH_MOTHERBOX_CONFIG_FILE` | `~/.config/motherbox/config`  |
| `$PATH_MOTHERBOX_BACKUPS`     | `~/.config/motherbox/backups` |

## Related Documentation

- [copying_configs.md](copying_configs.md) - `link_file` and `copy_file` usage
- [config_backups.md](config_backups.md) - `backup_file` and retention policy
- [common/](../common/) - `get_config` and `set_config`
