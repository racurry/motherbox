#!/bin/bash
# Common helper functions for setup scripts.

################################################################################
#                              INITIALIZATION
################################################################################

# Determine repo root relative to this file.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# COMMON_DIR is lib/bash, so bubble up two levels to reach the repo root.
REPO_ROOT="$(cd "${COMMON_DIR}/../.." && pwd)"

# Mother Box paths (this project's config and data)
PATH_MOTHERBOX_CONFIG="${HOME}/.config/motherbox"
PATH_MOTHERBOX_CONFIG_FILE="${PATH_MOTHERBOX_CONFIG}/config"
PATH_MOTHERBOX_BACKUPS="${PATH_MOTHERBOX_CONFIG}/backups"

################################################################################
#                            LOGGING & DISPLAY
################################################################################
# Provides colored console output for informational, warning, error, and
# success messages. All log functions write to stdout except log_warn and
# log_error which write to stderr.
#
# Functions:
#   log_info <message>     - Blue informational message
#   log_warn <message>     - Yellow warning (stderr)
#   log_error <message>    - Red error (stderr)
#   log_success <message>  - Green success message
#   log_debug <message>    - Purple debug message
#   fail <message>         - Log error and exit 1
#   print_heading <text>   - Cyan section heading
#
# Configuration:
#   LOG_FILE         - Path for log file (default: ~/.config/motherbox/logs/setup.log)
#   LOG_FILE_ENABLED - Set to "true" to enable file logging
#   LOG_DEBUG        - Set to "true" to enable debug output to console
#   UNATTENDED       - Set to "true" to skip interactive operations
################################################################################

# Global configuration defaults (only set if not already defined)
: "${LOG_TAG:=}"
: "${LOG_FILE:=${HOME}/.config/motherbox/logs/setup.log}"
: "${LOG_FILE_ENABLED:=false}"
: "${LOG_DEBUG:=false}"
: "${UNATTENDED:=false}"

# Color codes for readability.
CLR_RESET=$'\033[0m'      # reset / default
CLR_INFO=$'\033[1;34m'    # bright blue for informational messages
CLR_WARN=$'\033[1;33m'    # bright yellow for warnings
CLR_ERROR=$'\033[1;31m'   # bright red for errors
CLR_SUCCESS=$'\033[1;32m' # bright green for success messages
CLR_BOLD=$'\033[1m'       # bold text
CLR_CYAN=$'\033[1;36m'    # bright cyan for headings
CLR_DEBUG=$'\033[1;35m'   # bright magenta/purple for debug messages

# Internal helper to write to log file if enabled
_log_to_file() {
    if [[ "${LOG_FILE_ENABLED}" == "true" ]]; then
        printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"${LOG_FILE}"
    fi
}

log_info() {
    printf "%s[%s] %s%s\n" "${CLR_INFO}" "${LOG_TAG}" "$*" "${CLR_RESET}"
    _log_to_file "[INFO] $*"
}

log_warn() {
    printf "%s[%s] %s%s\n" "${CLR_WARN}" "${LOG_TAG}" "$*" "${CLR_RESET}" >&2
    _log_to_file "[WARN] $*"
}

log_error() {
    printf "%s[%s] %s%s\n" "${CLR_ERROR}" "${LOG_TAG}" "$*" "${CLR_RESET}" >&2
    _log_to_file "[ERROR] $*"
}

log_success() {
    printf "%s[%s] %s%s\n" "${CLR_SUCCESS}" "${LOG_TAG}" "$*" "${CLR_RESET}"
    _log_to_file "[SUCCESS] $*"
}

log_debug() {
    if [[ "${LOG_DEBUG}" == "true" ]]; then
        printf "%s[%s] %s%s\n" "${CLR_DEBUG}" "${LOG_TAG}" "$*" "${CLR_RESET}"
    fi
    _log_to_file "[DEBUG] $*"
}

fail() {
    log_error "$*"
    exit 1
}

print_heading() {
    local text="$1"
    printf "\n\033[1;36m==> %s\033[0m\n" "$text"
    _log_to_file "==> $text"
}

################################################################################
#                         CONFIGURATION MANAGEMENT
################################################################################
# Manages persistent configuration stored in ~/.config/motherbox/config.
# Config file uses shell variable format that can be sourced.
#
# Default values:
#   BACKUP_RETENTION_DAYS=60
#   PROFILE=           (empty, set by run/setup.sh)
#   MACHINE=           (empty, set by run/setup.sh)
#
# Functions:
#   ensure_config              - Create config file with defaults if missing
#   get_config <key>           - Get a config value (stdout)
#   set_config <key> <value>   - Set a config value
################################################################################

# _config_defaults returns default config values as shell assignments
_config_defaults() {
    cat <<'EOF'
BACKUP_RETENTION_DAYS=60
PROFILE=
MACHINE=
EOF
}

# ensure_config creates the config file with defaults if it doesn't exist.
# Called automatically by get_config and set_config.
# Silent by default to avoid disrupting output.
ensure_config() {
    if [[ -f "${PATH_MOTHERBOX_CONFIG_FILE}" ]]; then
        return 0
    fi

    mkdir -p "${PATH_MOTHERBOX_CONFIG}"
    _config_defaults >"${PATH_MOTHERBOX_CONFIG_FILE}"
}

# get_config retrieves a configuration value.
# Usage: get_config <key>
# Returns: The value via stdout, or empty string if not set
get_config() {
    local key="$1"

    ensure_config

    # Source config in subshell and echo the requested variable
    (
        # shellcheck source=/dev/null
        source "${PATH_MOTHERBOX_CONFIG_FILE}"
        eval "echo \"\${${key}:-}\""
    )
}

# set_config sets a configuration value.
# Usage: set_config <key> <value>
# Creates config file with defaults if it doesn't exist.
set_config() {
    local key="$1"
    local value="$2"

    ensure_config

    # Read current config
    local tmp_file
    tmp_file="$(mktemp)"

    # Update or add the key
    if grep -q "^${key}=" "${PATH_MOTHERBOX_CONFIG_FILE}"; then
        # Key exists, update it
        sed "s|^${key}=.*|${key}=${value}|" "${PATH_MOTHERBOX_CONFIG_FILE}" >"${tmp_file}"
    else
        # Key doesn't exist, append it
        cat "${PATH_MOTHERBOX_CONFIG_FILE}" >"${tmp_file}"
        echo "${key}=${value}" >>"${tmp_file}"
    fi

    mv "${tmp_file}" "${PATH_MOTHERBOX_CONFIG_FILE}"
}

################################################################################
#                           REQUIREMENT GUARDS
################################################################################
# Guard functions that verify prerequisites are met before proceeding.
# All guards call fail() if the requirement is not satisfied.
#
# Functions:
#   require_command <cmd>              - Ensure binary is in PATH
#   require_file <path>                - Ensure file exists
#   require_directory <path>           - Ensure directory exists
#   check_rosetta                      - Check if Rosetta 2 is running (returns 0/1)
#   require_rosetta                    - Ensure Rosetta 2 is installed
#   ensure_brew_package <cmd> [pkg] [type] - Install brew package if cmd missing
################################################################################

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail "Required command '$cmd' not found in PATH"
    fi
}

require_file() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        fail "Required file '$path' is missing"
    fi
}

require_directory() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        fail "Required directory '$path' is missing"
    fi
}

check_rosetta() {
    if ! pgrep -q oahd; then
        return 1
    fi
    return 0
}

require_rosetta() {
    if ! check_rosetta; then
        log_error "Rosetta 2 is not installed but is required"
        log_info "Install with: softwareupdate --install-rosetta --agree-to-license"
        fail "Rosetta 2 installation required"
    fi
}

# ensure_brew_package installs a Homebrew package if the command is not found.
# Usage: ensure_brew_package <command> [package] [type]
#   <command> - The CLI command to check for (e.g., "claude")
#   [package] - The Homebrew package to install (default: same as command)
#   [type]    - Package type: "cask", "formula", or omit for auto-detect
ensure_brew_package() {
    local cmd="$1"
    local pkg="${2:-$1}"
    local pkg_type="${3:-}"

    if command -v "${cmd}" &>/dev/null; then
        return 0
    fi

    print_heading "Installing ${pkg}"
    require_command brew

    case "${pkg_type}" in
    cask)
        brew install --cask "${pkg}"
        ;;
    formula)
        brew install --formula "${pkg}"
        ;;
    *)
        brew install "${pkg}"
        ;;
    esac
}

################################################################################
#                           BACKUP MANAGEMENT
################################################################################
# Manages file backups in ~/.config/motherbox/backups/.
# Backups are organized by date and app name, with automatic pruning of
# files older than BACKUP_RETENTION_DAYS (default: 60).
#
# Directory structure:
#   ~/.config/motherbox/backups/<YYYYMMDD>/<app_name>/<filename>.<timestamp>
#
# Functions:
#   prune_backups                        - Remove backups older than retention
#   backup_file <path> <app_name>        - Move file to backup location
################################################################################

# prune_backups removes backup files older than BACKUP_RETENTION_DAYS.
# Cleans up empty directories after pruning.
prune_backups() {
    if [[ ! -d "${PATH_MOTHERBOX_BACKUPS}" ]]; then
        return 0
    fi

    local retention_days
    retention_days="$(get_config BACKUP_RETENTION_DAYS)"
    retention_days="${retention_days:-60}" # Fallback if empty

    # Find and delete files older than retention period, logging each deletion
    while IFS= read -r -d '' file; do
        log_warn "Pruning old backup: ${file}"
        rm -f "$file"
    done < <(find "${PATH_MOTHERBOX_BACKUPS}" -type f -mtime "+${retention_days}" -print0 2>/dev/null)

    # Clean up empty directories
    find "${PATH_MOTHERBOX_BACKUPS}" -type d -empty -delete 2>/dev/null || true
}

# backup_file moves a file to the Mother Box backups directory.
# Triggers pruning of backups older than retention period.
backup_file() {
    local file_path="$1"
    local app_name="$2"

    if [[ -z "$app_name" ]]; then
        fail "backup_file requires app_name argument"
    fi

    if [[ ! -e "$file_path" ]]; then
        return 0
    fi

    local filename datestamp timestamp backup_dir backup_path
    filename="$(basename "$file_path")"
    datestamp="$(date +%Y%m%d)"
    timestamp="$(date +%Y%m%d_%H%M%S)"
    backup_dir="${PATH_MOTHERBOX_BACKUPS}/${datestamp}/${app_name}"
    backup_path="${backup_dir}/${filename}.${timestamp}"

    mkdir -p "$backup_dir"
    cp "$file_path" "$backup_path"
    log_warn "Backed up ${filename} to ${backup_path}"

    # Opportunistic pruning
    prune_backups
}

################################################################################
#                            FILE OPERATIONS
################################################################################
# Functions for creating symlinks and copying files with automatic backup
# of existing files. Use link_file when the target app follows symlinks;
# use copy_file when it doesn't.
#
# Functions:
#   link_file <src> <dest> <app_name>  - Create/update symlink with backup
#   copy_file <src> <dest> <app_name>  - Copy file with backup
################################################################################

# link_file creates or updates a symlink, backing up existing files if needed.
# - If destination is already a correct symlink, does nothing
# - If destination is a different symlink, replaces it (no backup needed)
# - If destination is a regular file, backs it up using backup_file
link_file() {
    local src="$1"
    local dest="$2"
    local app_name="$3"

    if [[ -z "${app_name}" ]]; then
        fail "link_file requires app_name argument"
    fi

    if [[ -L "${dest}" ]]; then
        local current_target
        current_target="$(readlink "${dest}")"
        if [[ "${current_target}" == "${src}" ]]; then
            log_info "Symlink already correct: ${dest}"
            return 0
        fi
        log_info "Replacing existing symlink ${dest}"
        rm "${dest}"
    elif [[ -e "${dest}" ]]; then
        backup_file "${dest}" "${app_name}"
        rm "${dest}"
    fi

    ln -s "${src}" "${dest}"
    log_info "Linked ${dest} -> ${src}"
}

# copy_file copies a file to destination, backing up existing files if needed.
# - If destination is a symlink, removes it and copies
# - If destination is a regular file, backs it up using backup_file
# Use this for apps that don't follow symlinks.
copy_file() {
    local src="$1"
    local dest="$2"
    local app_name="$3"

    if [[ -z "${app_name}" ]]; then
        fail "copy_file requires app_name argument"
    fi

    if [[ -L "${dest}" ]]; then
        log_info "Removing existing symlink ${dest}"
        rm "${dest}"
    elif [[ -e "${dest}" ]]; then
        backup_file "${dest}" "${app_name}"
    fi

    cp "${src}" "${dest}"
    log_info "Copied ${src} -> ${dest}"
}

################################################################################
#                         DOTFILE LINKING SUGAR
################################################################################
# Convenience wrappers around link_file for common patterns.
#
# Functions:
#   link_home_dotfile <filepath> <app_name>  - Link file to ~/
#   link_xdg_config <filepath> <app_name>    - Link file to ~/.config/{app_name}/
################################################################################

# link_home_dotfile links a file to the HOME directory.
# Usage: link_home_dotfile <filepath> <app_name>
#   Links /path/to/.gitconfig -> ~/.gitconfig
link_home_dotfile() {
    local src="$1"
    local app_name="$2"
    local filename
    filename="$(basename "${src}")"
    local dest="${HOME}/${filename}"

    require_file "${src}"
    link_file "${src}" "${dest}" "${app_name}"
}

# link_xdg_config links a file to ~/.config/{app_name}/.
# Creates the target directory if it doesn't exist.
# Usage: link_xdg_config <filepath> <app_name>
#   Links /path/to/config.toml -> ~/.config/{app_name}/config.toml
link_xdg_config() {
    local src="$1"
    local app_name="$2"
    local filename
    filename="$(basename "${src}")"
    local target_dir="${HOME}/.config/${app_name}"
    local dest="${target_dir}/${filename}"

    require_file "${src}"
    mkdir -p "${target_dir}"
    link_file "${src}" "${dest}" "${app_name}"
}

################################################################################
#                            SETUP MODE
################################################################################
# Determines and manages the setup mode (galileo/personal) for the system.
# Mode can come from: command-line flag > config file > interactive prompt.
#
# Functions:
#   prompt_profile              - Interactive prompt for mode selection
#   determine_profile [options] - Resolve mode from all sources
#
# Options for determine_profile:
#   --reset        Ignore saved config, force prompt
#   --unattended   Skip prompting, fail if mode unknown
#   --profile=MODE    Pre-set mode (takes precedence)
################################################################################

# prompt_profile prompts user interactively for setup mode selection.
# Sets PROFILE global variable.
prompt_profile() {
    print_heading "Setup Mode Selection"
    echo "Please select your setup mode:"
    echo "  1) galileo  - Install Galileo work-specific tools & settings"
    echo "  2) personal - Install personal-specific tools & settings"
    echo ""

    while true; do
        read -rp "Enter your choice (1 or 2): " choice
        case $choice in
        1 | galileo)
            PROFILE="galileo"
            break
            ;;
        2 | personal)
            PROFILE="personal"
            break
            ;;
        *)
            echo "Invalid choice. Please enter 1 (galileo) or 2 (personal)"
            ;;
        esac
    done
}

# determine_profile resolves setup mode from flags, config, or prompt.
# Sets PROFILE global variable and persists to config.
#
# Usage: determine_profile "$@"
#
# Recognized flags: --profile MODE, --reset, --reset-profile, --unattended
# Precedence: --profile flag > config file > interactive prompt
# Returns: 0 on success, 1 if mode could not be determined
#
# Ignores unrecognized arguments, so callers can pass "$@" directly.
determine_profile() {
    local reset_mode=false
    local unattended=false
    local mode_override=""

    # Parse arguments (ignores unrecognized args)
    while [[ $# -gt 0 ]]; do
        case $1 in
        --reset | --reset-profile)
            reset_mode=true
            shift
            ;;
        --unattended)
            unattended=true
            shift
            ;;
        --profile)
            mode_override="${2:-}"
            shift 2
            ;;
        *) shift ;;
        esac
    done

    # Check command-line override first
    if [[ -n "${mode_override}" ]]; then
        PROFILE="${mode_override}"
    # Check config unless reset requested
    elif [[ "${reset_mode}" != "true" ]]; then
        PROFILE="$(get_config PROFILE)"
    fi

    # Prompt if still not set
    if [[ -z "${PROFILE:-}" ]]; then
        if [[ "${unattended}" == "true" ]]; then
            log_error "Setup mode not set and --unattended prevents prompting"
            log_info "Use --profile=work or --profile=personal to set mode"
            return 1
        fi
        prompt_profile
    fi

    # Persist and report
    set_config PROFILE "${PROFILE}"
    log_info "Setup mode: ${PROFILE}"
    return 0
}

# determine_machine resolves machine name from flags or config.
# Sets MACHINE global variable and persists to config.
# Unlike profile, machine is optional — not all setups target a specific machine.
#
# Usage: determine_machine "$@"
#
# Recognized flags: --machine MACHINE
# Precedence: --machine flag > config file
determine_machine() {
    local machine_override=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --machine)
            machine_override="${2:-}"
            shift 2
            ;;
        *) shift ;;
        esac
    done

    if [[ -n "${machine_override}" ]]; then
        MACHINE="${machine_override}"
    else
        MACHINE="$(get_config MACHINE)"
    fi

    if [[ -n "${MACHINE}" ]]; then
        set_config MACHINE "${MACHINE}"
        log_info "Machine: ${MACHINE}"
    fi
}

################################################################################
#                         ARGUMENT PARSING HELPERS
################################################################################
# Helpers for parsing command-line arguments consistently across scripts.
#
# Functions:
#   check_global_flag "$@" - Check if arg is a known global flag
#                           Returns 0 and echoes shift count if recognized
#                           Returns 1 if not a global flag
#
# Global flags recognized by run/setup.sh and passed to all scripts:
#   --profile MODE      Setup profile (galileo/personal)
#   --machine MACHINE   Target machine (e.g., mini)
#   --reset-profile     Reset saved profile
#   --unattended     Skip interactive operations
#   --debug          Enable debug output
#   --logging        Enable file logging
################################################################################

# check_global_flag determines if an argument is a known global flag.
# Returns 0 and outputs shift count if recognized, returns 1 otherwise.
# Usage:
#   if shift_count=$(check_global_flag "$@"); then
#       shift $shift_count
#   else
#       # handle unknown arg
#   fi
check_global_flag() {
    case $1 in
    --profile | --machine)
        # Flag takes a value, consume both
        if [[ $# -ge 2 ]]; then
            echo 2
        else
            echo 1
        fi
        return 0
        ;;
    --reset-profile | --unattended | --debug | --logging)
        # Boolean flags, consume one arg
        echo 1
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

################################################################################
#                               EXPORTS
################################################################################

export REPO_ROOT
export CLR_RESET CLR_INFO CLR_WARN CLR_ERROR CLR_SUCCESS CLR_BOLD CLR_CYAN
