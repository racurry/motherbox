#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Manage Homebrew installation and package management.

Commands:
    setup       Run full setup (install Homebrew, then install packages)
    install     Install Homebrew if not already installed
    bundle      Install packages from Brewfile(s)
    audit       Audit installed apps against Brewfile definitions
    maintain    Run regular Homebrew maintenance (update, upgrade, cleanup)
    help        Show this help message (also: -h, --help)

Options:
    --profile MODE   Set to 'galileo' or 'personal' to install mode-specific packages
                  from apps/brew/galileo.Brewfile or apps/brew/personal.Brewfile
                  in addition to the main apps/brew/Brewfile
Brewfile Structure:
    Brewfile              Common packages (brew, cask, vscode)
    {mode}.Brewfile       Mode-specific packages
EOF
}

install_homebrew() {
    print_heading "Install Homebrew"

    require_command curl

    brew_path="/opt/homebrew/bin/brew"
    if [[ -x "${brew_path}" ]]; then
        # Homebrew is already installed; but is it sourced?
        if command -v brew >/dev/null 2>&1; then
            log_info "Homebrew already installed"
            return 0
        fi
        eval "$(${brew_path} shellenv)"
        if command -v brew >/dev/null 2>&1; then
            log_info "Homebrew installed, but not sourced; environment updated for this shell"
            return 0
        fi
    fi

    log_info "Installing Homebrew"
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        log_warn "Homebrew installer completed. Configure your shell environment, then rerun setup."
        log_warn "Add this to your shell profile (and run it in the current shell):"
        log_warn "  eval \"\$(/opt/homebrew/bin/brew shellenv)\""
        log_warn "After updating your profile, open a new shell or source the file so 'brew' is on PATH, then rerun setup."
        exit 2
    else
        fail "Homebrew installer failed"
    fi
}

install_bundle() {
    print_heading "Install Homebrew bundle"

    require_command brew

    # Always install the main Brewfile first
    main_manifest="${REPO_ROOT}/apps/brew/Brewfile"
    [[ -f "${main_manifest}" ]] || fail "Missing main Brewfile at ${main_manifest}"

    log_info "Installing common packages from main Brewfile"
    install_brewfile "${main_manifest}"

    # Install mode-specific packages
    mode_manifest="${REPO_ROOT}/apps/brew/${PROFILE}.Brewfile"
    if [[ -f "${mode_manifest}" ]]; then
        log_info "Installing ${PROFILE}-specific packages from ${mode_manifest}"
        install_brewfile "${mode_manifest}"
    else
        log_warn "No ${PROFILE}-specific Brewfile found at ${mode_manifest}"
    fi

}

maintain_brew() {
    print_heading "Homebrew Maintenance"

    require_command brew

    log_info "Updating Homebrew"
    brew update

    log_info "Upgrading installed packages"
    brew upgrade

    log_info "Removing unused dependencies"
    brew autoremove

    log_info "Cleaning up old versions and cache"
    brew cleanup

    log_success "Homebrew maintenance complete"
}

install_brewfile() {
    local manifest="$1"

    log_info "Running brew bundle install for ${manifest}"
    set +e
    brew bundle install --force --file="${manifest}"
    bundle_status=$?
    set -e

    if [[ ${bundle_status} -eq 0 ]]; then
        log_info "Brew bundle succeeded for ${manifest}"
        return 0
    fi

    log_warn "brew bundle reported errors for ${manifest}"

    log_warn "Running brew bundle check"
    if brew bundle check --file="${manifest}" >/dev/null 2>&1; then
        log_warn "brew bundle check reports all items installed for ${manifest}"
    else
        log_warn "brew bundle check indicates missing items for ${manifest}"
    fi
}

main() {
    local command=""
    local args=("$@")

    while [[ $# -gt 0 ]]; do
        case "$1" in
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup | install | bundle | audit | maintain)
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
        determine_profile "${args[@]}" || exit 1
        install_homebrew
        install_bundle
        ;;
    install)
        install_homebrew
        ;;
    bundle)
        determine_profile "${args[@]}" || exit 1
        install_bundle
        ;;
    audit)
        "${SCRIPT_DIR}/audit_apps.py"
        ;;
    maintain)
        maintain_brew
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"
