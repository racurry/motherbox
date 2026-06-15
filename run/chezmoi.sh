#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/bash/common.sh
source "${SCRIPT_DIR}/../lib/bash/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <chezmoi command> [args]

Run chezmoi using Mother Box's repo-local source state.

Examples:
  ./run/chezmoi.sh diff ~/.zshrc
  ./run/chezmoi.sh apply ~/.zshrc
  ./run/chezmoi.sh verify ~/.zshrc

EOF
}

main() {
    case "${1:-}" in
    "" | help | --help | -h)
        show_help
        exit 0
        ;;
    esac

    require_command chezmoi
    chezmoi --source "${REPO_ROOT}" "$@"
}

main "$@"
