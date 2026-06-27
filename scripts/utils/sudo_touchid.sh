#!/bin/bash
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: sudo_touchid.sh [--help]

Enable Touch ID authentication for sudo by managing /etc/pam.d/sudo_local.
EOF
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
esac

# macOS includes /etc/pam.d/sudo_local from /etc/pam.d/sudo and preserves it
# across OS updates, so we own sudo_local instead of editing /etc/pam.d/sudo
# (which is reset on update and can lock sudo out if malformed). pam_tid is
# "sufficient": a fingerprint satisfies auth, and if Touch ID is unavailable
# sudo falls through to the normal password prompt.

SUDO_LOCAL="/etc/pam.d/sudo_local"

DESIRED="$(
    cat <<'EOF'
# sudo_local: managed by motherbox — enables Touch ID for sudo.
auth       sufficient     pam_tid.so
EOF
)"

if [[ -f "$SUDO_LOCAL" && "$(cat "$SUDO_LOCAL")" == "$DESIRED" ]]; then
    echo "Touch ID for sudo already enabled"
    exit 0
fi

echo "Enabling Touch ID for sudo"
printf '%s\n' "$DESIRED" | /usr/bin/sudo tee "$SUDO_LOCAL" >/dev/null
