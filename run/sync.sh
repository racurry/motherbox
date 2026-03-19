#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/bash/common.sh
source "${SCRIPT_DIR}/../lib/bash/common.sh"

# Create ~/.config/motherbox/scripts symlink to repo scripts
# This provides a stable path for PATH that survives repo moves/renames

config_dir="$HOME/.config/motherbox"
scripts_link="$config_dir/scripts"
target="${REPO_ROOT}/scripts"

mkdir -p "$config_dir"

if [[ -L "$scripts_link" ]]; then
    current_target="$(readlink "$scripts_link")"
    if [[ "$current_target" == "$target" ]]; then
        log_info "Scripts symlink already correct: $scripts_link"
        exit 0
    fi
    rm "$scripts_link"
elif [[ -e "$scripts_link" ]]; then
    fail "$scripts_link exists but is not a symlink"
fi

ln -s "$target" "$scripts_link"
log_success "Created symlink: $scripts_link → $target"
