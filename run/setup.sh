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
  --unattended     Skip operations requiring human interaction
  --reset-mode     Ignore saved mode and prompt for selection
  --mode MODE      Set mode directly (galileo or personal)
  --debug          Enable debug output
  --logging        Enable logging to ~/.config/motherbox/setup.log
  -h, --help       Show this help message and exit

CONFIGURATION:
  Configuration is persisted to ~/.config/motherbox/config

EXAMPLES:
  # First run
  ./run/setup.sh

  # Override saved mode, persist new mode
  ./run/setup.sh --mode galileo

  # Non-interactive setup (skip operations that need you, eg sudo)
  ./run/setup.sh --unattended

EOF
}

# Override common.sh defaults and export for child scripts
export LOG_TAG="setup"
export LOG_FILE="${HOME}/.config/motherbox/setup.log"

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

# Initialize log file if logging is enabled
if [[ "${LOG_FILE_ENABLED}" == "true" ]]; then
    mkdir -p "$(dirname "${LOG_FILE}")"
    echo "=== Setup started at $(date) ===" >"${LOG_FILE}"
fi

# Determine setup mode (precedence: flag > config > prompt)
determine_setup_mode ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"} || exit 1

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

# Create ~/.config/motherbox/bin symlink
"${SCRIPT_DIR}/sync-bin.sh"

# Run an app setup script, handling exit codes
# Passes ORIGINAL_ARGS to each script so they receive --mode, --unattended, etc.
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

print_heading "Baseline Required Apps"
run_app_setup brew

print_heading "Shell Settings"
run_app_setup zsh

print_heading "macOS Settings"
run_app_setup macos
run_app_setup icloud

print_heading "Dev Tools"
run_app_setup asdf
run_app_setup git
run_app_setup direnv
run_app_setup 1password
run_app_setup shellcheck
run_app_setup markdownlint
run_app_setup mdformat
run_app_setup shfmt
run_app_setup ruff
run_app_setup uv

print_heading "Application Settings"
run_app_setup claudecode
run_app_setup gemini-cli
run_app_setup codex-cli
run_app_setup karabiner
