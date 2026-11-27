#!/bin/bash
# Run `herdr-app check` on Motherbox's Herdr mods.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: check-mods.sh [mod...]

Run `herdr-app check` on each mod in home/dot_config/herdr-app/mods/, or only
on the mods named. The check reads the source folders in this checkout, so it
works before `chezmoi apply` and in a worktree. Herdr must be running.

Exits nonzero at the first mod that fails, with Herdr's error.
EOF
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

mods_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../home/dot_config/herdr-app/mods" && pwd)"

if (( $# )); then
    mods=("$@")
else
    mods=()
    for dir in "$mods_dir"/*/; do
        mods+=("$(basename "$dir")")
    done
fi

for mod in "${mods[@]}"; do
    herdr-app check "$mods_dir/$mod"
done
