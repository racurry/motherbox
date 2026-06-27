#!/bin/bash
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: SUDO_ASKPASS=scripts/utils/sudo_askpass_1password.sh sudo -A <command>

A SUDO_ASKPASS helper that returns the local account password from 1Password
via the `op` CLI, so sudo can authenticate without an interactive prompt.

Experimental and standalone — NOT wired into `mother`, which uses Touch ID for
sudo (pam_tid). This is a place to experiment with askpass-based flows (headless
/ SSH / CI contexts where Touch ID isn't available).

Configuration:
  SUDO_ASKPASS_OP_REF   1Password secret reference for the password item.
                        Default: op://Private/macOS sudo/password

Requirements:
  - The 1Password CLI (op) installed.
  - op able to authenticate (desktop-app integration / Touch ID, or `op signin`).
  - A 1Password item holding this Mac's local account password at the ref above.

Test it directly (prints the secret, triggers 1Password auth):
  SUDO_ASKPASS_OP_REF='op://...' ./scripts/utils/sudo_askpass_1password.sh
EOF
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
esac

OP_REF="${SUDO_ASKPASS_OP_REF:-op://Private/6euzxhv4cqkmutxl6n5ioegd4y/password}"

# Resolve op explicitly: sudo runs the askpass helper with a sanitized PATH, so
# a bare `op` may not be found even when it is installed.
op_bin="$(command -v op || true)"
if [[ -z "$op_bin" ]]; then
    for candidate in /opt/homebrew/bin/op /usr/local/bin/op; do
        if [[ -x "$candidate" ]]; then
            op_bin="$candidate"
            break
        fi
    done
fi

if [[ -z "$op_bin" ]]; then
    echo "sudo_askpass_1password: the 1Password CLI (op) is not installed" >&2
    exit 1
fi

# op prints the secret to stdout; --no-newline keeps it clean for sudo. On any
# failure (not signed in, ref not found) op exits non-zero with an error on
# stderr, so sudo gets empty input and fails the auth cleanly.
exec "$op_bin" read --no-newline "$OP_REF"
