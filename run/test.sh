#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat <<EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Run tests for the macOS setup repository.

COMMANDS:
  lint      Run shellcheck linting on all bash scripts
  unit      Run bats unit tests
  all       Run both lint and unit tests (default)

OPTIONS:
  -h, --help        Show this help message and exit
  --app APP_NAME    Run tests for a specific app only

PREREQUISITES:
  - shellcheck (install with: brew install shellcheck)
  - bats-core (install with: brew install bats-core)

EXIT CODES:
  0 - All tests passed
  1 - One or more tests failed

EXAMPLES:
  $(basename "$0")               # Run all tests (lint + unit)
  $(basename "$0") lint          # Run only shellcheck
  $(basename "$0") unit          # Run only unit tests
  $(basename "$0") --app brew    # Run only tests for apps/brew/
  $(basename "$0") lint --app git # Lint only apps/git/ scripts

EOF
}

run_lint() {
    local app_filter="${1:-}"

    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "shellcheck not found; install with 'brew install shellcheck'" >&2
        return 1
    fi

    if [[ -n "$app_filter" ]]; then
        echo "Running shellcheck linting for app: ${app_filter}..."
    else
        echo "Running shellcheck linting..."
    fi

    bash_sources=()
    if [[ -n "$app_filter" ]]; then
        # Only lint scripts in the specified app directory
        if [[ -d "${SCRIPT_DIR}/../apps/${app_filter}" ]]; then
            while IFS= read -r file; do
                bash_sources+=("$file")
            done < <(find "${SCRIPT_DIR}/../apps/${app_filter}" -name '*.sh' -print | sort)
        else
            echo "App directory not found: apps/${app_filter}" >&2
            return 1
        fi
    else
        # Lint all scripts in directories that exist
        local search_dirs=()
        for dir in "${SCRIPT_DIR}/../lib/bash" "${SCRIPT_DIR}/../scripts" "${SCRIPT_DIR}/../apps"; do
            [[ -d "$dir" ]] && search_dirs+=("$dir")
        done
        if [[ ${#search_dirs[@]} -gt 0 ]]; then
            while IFS= read -r file; do
                bash_sources+=("$file")
            done < <(find "${search_dirs[@]}" -name '*.sh' -print | sort)
        fi
    fi

    if [ ${#bash_sources[@]} -eq 0 ]; then
        echo "No bash sources found" >&2
        return 0
    fi

    echo "Checking ${#bash_sources[@]} bash files..."
    shellcheck -x --source-path="${SCRIPT_DIR}/.." "${bash_sources[@]}"
    echo "✓ All bash files passed shellcheck"
}

run_unit() {
    local app_filter="${1:-}"

    if ! command -v bats >/dev/null 2>&1; then
        echo "bats not found; install with 'brew install bats-core'" >&2
        return 1
    fi

    if [[ -n "$app_filter" ]]; then
        echo "Running unit tests for app: ${app_filter}..."

        # Find test file for the specified app
        test_file="${SCRIPT_DIR}/../apps/${app_filter}/test_${app_filter}.bats"
        if [[ ! -f "$test_file" ]]; then
            echo "Test file not found: ${test_file}" >&2
            return 1
        fi

        bats "$test_file"
    else
        echo "Running unit tests..."

        # Discover all test files in apps/, scripts/, and lib/
        local test_files=()
        for pattern in "${SCRIPT_DIR}"/../apps/*/test_*.bats \
            "${SCRIPT_DIR}"/../scripts/test_*.bats \
            "${SCRIPT_DIR}"/../lib/test_*.bats; do
            [[ -e "$pattern" ]] && test_files+=("$pattern")
        done

        if [[ ${#test_files[@]} -eq 0 ]]; then
            echo "No test files found" >&2
            return 0
        fi

        bats "${test_files[@]}"
    fi
}

# Parse arguments
COMMAND="all"
APP_FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        show_help
        exit 0
        ;;
    --app)
        if [[ -z "${2:-}" ]]; then
            echo "Error: --app requires an app name" >&2
            show_help
            exit 1
        fi
        APP_FILTER="$2"
        shift 2
        ;;
    lint | unit | all)
        COMMAND="$1"
        shift
        ;;
    *)
        echo "Unknown argument: $1" >&2
        show_help
        exit 1
        ;;
    esac
done

case "$COMMAND" in
lint)
    run_lint "$APP_FILTER"
    ;;
unit)
    run_unit "$APP_FILTER"
    ;;
all)
    run_lint "$APP_FILTER"
    echo ""
    run_unit "$APP_FILTER"
    echo ""
    if [[ -n "$APP_FILTER" ]]; then
        echo "All tests for app '${APP_FILTER}' completed successfully!"
    else
        echo "All tests completed successfully!"
    fi
    ;;
*)
    echo "Unknown command: $COMMAND" >&2
    show_help
    exit 1
    ;;
esac
