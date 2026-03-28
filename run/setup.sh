#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/bash/common.sh
source "${SCRIPT_DIR}/../lib/bash/common.sh"

# Save original args to pass through to child scripts
ORIGINAL_ARGS=("$@")

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Automated macOS setup script that installs and configures development tools,
applications, and system settings.

OPTIONS:
  --profile PROFILE   Set profile (galileo or personal)
  --machine MACHINE   Set machine (e.g., mini) for machine-specific setup
  --reset-profile     Ignore saved profile and prompt for selection
  --unattended        Skip operations requiring human interaction
  --debug             Enable debug output
  --logging           Enable logging to ~/.config/motherbox/logs/setup.log
  -h, --help          Show this help message and exit

CONFIGURATION:
  Configuration is persisted to ~/.config/motherbox/config

EXAMPLES:
  # First run
  ./run/setup.sh

  # Set profile, persist it
  ./run/setup.sh --profile galileo

  # Set up the Mac Mini specifically
  ./run/setup.sh --profile personal --machine mini

  # Non-interactive setup (skip operations that need you, eg sudo)
  ./run/setup.sh --unattended

EOF
}

# Override common.sh defaults and export for child scripts
export LOG_TAG="setup"
export LOG_FILE="${HOME}/.config/motherbox/logs/setup.log"

# Parse command line arguments (may override defaults above)
for arg in "$@"; do
    case $arg in
    -h | --help)
        show_help
        exit 0
        ;;
    --unattended)
        export UNATTENDED=true
        ;;
    --debug)
        export LOG_DEBUG=true
        ;;
    --logging)
        export LOG_FILE_ENABLED=true
        ;;
    esac
done

# Ensure logs directory exists
mkdir -p "${HOME}/.config/motherbox/logs"

# Initialize log file if logging is enabled
if [[ "${LOG_FILE_ENABLED}" == "true" ]]; then
    mkdir -p "$(dirname "${LOG_FILE}")"
    echo "=== Setup started at $(date) ===" >"${LOG_FILE}"
fi

# Determine profile (precedence: flag > config > prompt)
determine_profile ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"} || exit 1

# Determine machine (optional, precedence: flag > config)
determine_machine ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"}

# Preflight checks
preflight_checks() {
    print_heading "System Requirements Check"
    log_info "Running preflight checks..."

    # Block running as root
    if [[ $EUID -eq 0 ]]; then
        fail "Run this setup as a regular user, not root"
    fi

    if [[ "$(pwd)" != "${REPO_ROOT}" ]]; then
        log_info "Changing working directory to ${REPO_ROOT}"
        cd "${REPO_ROOT}"
    fi

    log_info "Repository root resolved to ${REPO_ROOT}"
    log_info "Bash version ${BASH_VERSION}"

    # Xcode Command Line Tools are required for everything else
    "${REPO_ROOT}/apps/xcodecli/xcodecli.sh" setup

    log_info "All preflight checks passed"
}

# Run preflight checks before anything else
preflight_checks

# Create ~/.config/motherbox/scripts symlink
"${SCRIPT_DIR}/sync.sh"

# Run an app setup script, handling exit codes
# Passes ORIGINAL_ARGS to each script so they receive --profile, --unattended, etc.
run_app_setup() {
    local app="$1"
    local script="${REPO_ROOT}/apps/${app}/${app}.sh"
    set +e
    "${script}" setup ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"}
    local status=$?
    set -e

    case ${status} in
    0) ;;
    2)
        log_warn "${app} requested manual follow-up; rerun once complete"
        exit 2
        ;;
    *)
        fail "${app} exited with status ${status}"
        ;;
    esac
}

# ==========================================================================
# PHASE 1: BOOTSTRAP — core dev environment
# ==========================================================================

print_heading "Phase 1: Bootstrap"

# Install Homebrew + core formulae only
"${REPO_ROOT}/apps/brew/brew.sh" bootstrap ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"}

# Source Homebrew into this shell so downstream scripts can find brew-installed tools
if ! command -v brew >/dev/null 2>&1; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

run_app_setup zsh
run_app_setup asdf

# Source asdf into this shell so downstream scripts can find asdf-managed runtimes
# shellcheck source=/dev/null
asdf_sh="$(brew --prefix)/opt/asdf/libexec/asdf.sh"
if [[ -f "${asdf_sh}" ]] && ! command -v asdf >/dev/null 2>&1; then
    . "${asdf_sh}"
fi

run_app_setup git
run_app_setup direnv
run_app_setup 1password
run_app_setup shellcheck
run_app_setup markdownlint
run_app_setup shfmt
run_app_setup ruff
run_app_setup uv

# Ensure ~/.local/bin is on PATH (uv installs there)
if [[ -d "${HOME}/.local/bin" ]] && [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
fi

print_heading "Bootstrap complete"

# ==========================================================================
# PHASE 2: FULL INSTALL — all apps, settings, and preferences
# ==========================================================================

print_heading "Phase 2: Full Install"

run_app_setup brew

print_heading "macOS Settings"
run_app_setup macos
run_app_setup icloud

run_app_setup mdformat

print_heading "Mac App Store"
run_app_setup mas

print_heading "Application Settings"
run_app_setup vscode
run_app_setup claudecode
run_app_setup gemini-cli
run_app_setup codex-cli
run_app_setup karabiner

# Run machine-specific setup if a machine is specified
if [[ -n "${MACHINE:-}" ]]; then
    machine_script="${REPO_ROOT}/machines/${MACHINE}/${MACHINE}.sh"
    if [[ -x "${machine_script}" ]]; then
        print_heading "Machine Setup: ${MACHINE}"
        "${machine_script}" setup
    else
        log_warn "No machine script found at ${machine_script}"
    fi
fi
