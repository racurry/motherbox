#!/bin/bash

# Folder structure — create the standard directory layout.
#
# Triggered by chezmoi via home/.chezmoiscripts/run_onchange_after_30-folders.sh.tmpl
# whenever this script (or the active profile) changes; also runnable by hand at
# any time. Creating folders is idempotent. Removing an entry below does NOT
# delete the folder on disk — prune deliberately by hand.
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: folders.sh [--help]

Create the standard folder structure under ~, ~/dev and ~/Documents. The
firsthand set (~/fh) is created only when the active profile is "firsthand". The
profile comes from chezmoi's config (~/.config/chezmoi/chezmoi.toml) and can be
overridden with MOTHERBOX_PROFILE. Idempotent; never deletes anything.
EOF
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
esac

# ==========================================================================
# The declarative list. Paths are relative to the base dir each array names.
# ==========================================================================

# ~/dev — personal projects (every profile)
DEV=(
    vendor
)

# ~ (profile "firsthand" only)
HOME_DIRS_FIRSTHAND=(
    fh
)

# ~/Documents
DOCUMENTS=(
    "@auto"
    000_Inbox
    100_Areas
    200_People
    300_Time
    400_Topics
    500_Projects
    600_Output
    800_Libraries
    900_Sharing
    999_Meta
)

# ~
HOME_DIRS=(
    skynet
)

# ==========================================================================
# Profile — persisted by chezmoi, but this script has to work without chezmoi
# installed, so read the value straight out of the TOML instead of shelling out
# to `chezmoi data`.
# ==========================================================================

CHEZMOI_CONFIG="$HOME/.config/chezmoi/chezmoi.toml"

profile="${MOTHERBOX_PROFILE:-}"
if [[ -z "$profile" && -f "$CHEZMOI_CONFIG" ]]; then
    profile=$(sed -n 's/^[[:space:]]*profile[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$CHEZMOI_CONFIG" | head -1)
fi
profile="${profile:-personal}"

# ==========================================================================
# Create
# ==========================================================================

make_dirs() {
    local base="$1"
    shift

    local rel
    for rel in "$@"; do
        mkdir -p "${base}/${rel}"
    done
}

echo "==> Folders: ensure structure (profile: ${profile})"

make_dirs "$HOME/dev" "${DEV[@]}"
if [[ "$profile" == "firsthand" ]]; then
    make_dirs "$HOME" "${HOME_DIRS_FIRSTHAND[@]}"
fi
make_dirs "$HOME/Documents" "${DOCUMENTS[@]}"
make_dirs "$HOME" "${HOME_DIRS[@]}"
