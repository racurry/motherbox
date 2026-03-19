#!/bin/bash
# Sign ad-hoc binaries so macOS TCC / FDA grants persist across updates.
#
# macOS won't remember "Allow" for linker-signed/ad-hoc binaries (common with
# uv, Homebrew, asdf-managed Python, Node, etc.).  This tool creates a local
# code-signing identity once, then re-signs any binary you point it at.
#
# Usage:
#   tcc-sign.sh <binary>         Sign a single binary
#   tcc-sign.sh refresh          Re-sign all previously signed binaries
#   tcc-sign.sh setup            Create the signing identity only
#   tcc-sign.sh check <binary>   Show current signature of a binary
#   tcc-sign.sh list             List binaries you've signed
#   tcc-sign.sh help             Show this help message
#
# First run creates a self-signed certificate called "TCC Local Signer"
# in your login keychain.  You'll be prompted for your macOS password once
# to mark it as trusted for code signing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../lib/bash/common.sh"

CERT_NAME="TCC Local Signer"
CERT_DAYS=3650
SIGNED_LOG="${PATH_MOTHERBOX_CONFIG}/tcc-sign.log"

# ── helpers ──────────────────────────────────────────────────────────────────

identity_exists() {
    security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"
}

ensure_identity() {
    if identity_exists; then
        return 0
    fi

    log_info "Creating code-signing identity \"$CERT_NAME\" …"

    local tmpdir
    tmpdir=$(mktemp -d)

    # Generate self-signed cert with code-signing EKU
    openssl req -x509 -newkey rsa:2048 \
        -keyout "$tmpdir/key.pem" -out "$tmpdir/cert.pem" \
        -days "$CERT_DAYS" -nodes -subj "/CN=$CERT_NAME" \
        -addext "basicConstraints=CA:FALSE" \
        -addext "keyUsage=digitalSignature" \
        -addext "extendedKeyUsage=codeSigning" \
        2>/dev/null

    # Package as PKCS12 and import to login keychain
    openssl pkcs12 -export \
        -out "$tmpdir/cert.p12" \
        -inkey "$tmpdir/key.pem" \
        -in "$tmpdir/cert.pem" \
        -passout pass:tcc-sign-temp \
        -legacy \
        2>/dev/null

    security import "$tmpdir/cert.p12" \
        -k ~/Library/Keychains/login.keychain-db \
        -T /usr/bin/codesign \
        -P tcc-sign-temp

    # Mark trusted for code signing (prompts for macOS password)
    log_info "Trusting certificate for code signing (you may be prompted for your password) …"
    security add-trusted-cert -d -r trustRoot -p codeSign \
        -k ~/Library/Keychains/login.keychain-db \
        "$tmpdir/cert.pem"

    rm -rf "$tmpdir"

    if identity_exists; then
        log_success "Identity \"$CERT_NAME\" created and trusted."
    else
        fail "Certificate was imported but codesign can't find it.
    Open Keychain Access → login → My Certificates → \"$CERT_NAME\"
    → Get Info → Trust → Code Signing → set to \"Always Trust\"."
    fi
}

record_binary() {
    local resolved="$1"
    mkdir -p "$(dirname "$SIGNED_LOG")"
    echo "$resolved" >>"$SIGNED_LOG"
    sort -u "$SIGNED_LOG" -o "$SIGNED_LOG"
}

prompt_fda() {
    local resolved="$1"
    local do_open="${2:-false}"
    local dir
    dir="$(dirname "$resolved")"

    log_warn "This binary needs Full Disk Access (FDA) to access other apps' data."
    log_warn "macOS requires you to add it manually in System Settings."
    echo ""
    log_info "Drag the binary into the FDA list, or click '+' and navigate to it."
    echo ""
    log_info "Binary:     $resolved"
    log_info "FDA pane:   open \"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles\""
    log_info "Binary dir: open \"$dir\""

    if [[ "$do_open" == "true" ]]; then
        echo ""
        log_info "Opening System Settings and binary folder..."
        open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        open "$dir"
    fi
}

sign_binary() {
    local binary="$1"

    # Resolve symlinks to get the real binary
    local resolved
    resolved=$(readlink -f "$binary") || fail "Cannot resolve path: $binary"
    [ -f "$resolved" ] || fail "Not a file: $resolved"

    log_info "Signing $resolved …"
    codesign -s "$CERT_NAME" -f "$resolved" 2>&1

    log_success "Signed $resolved"
    codesign -dvv "$resolved" 2>&1 | grep -E '(Identifier|Signature|Authority|TeamIdentifier|flags)'

    record_binary "$resolved"
}

# ── commands ─────────────────────────────────────────────────────────────────

do_sign() {
    local binary="${1:-}"
    [ -n "$binary" ] || fail "Usage: tcc-sign.sh <binary>"
    ensure_identity
    sign_binary "$binary"
}

do_ensure_fda() {
    local do_open=false
    local binary=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --open)
            do_open=true
            shift
            ;;
        *)
            binary="$1"
            shift
            ;;
        esac
    done

    [ -n "$binary" ] || fail "Usage: tcc-sign.sh ensure-fda [--open] <binary>"

    local resolved
    resolved=$(readlink -f "$binary") || fail "Cannot resolve path: $binary"
    [ -f "$resolved" ] || fail "Not a file: $resolved"

    prompt_fda "$resolved" "$do_open"
}

do_refresh() {
    if [ ! -f "$SIGNED_LOG" ]; then
        log_warn "No binaries signed yet. Nothing to refresh."
        return 0
    fi

    ensure_identity

    print_heading "Refreshing TCC signatures"
    local count=0
    local skipped=0
    # Read into array first — sign_binary modifies the log file
    local binaries=()
    while IFS= read -r bin; do
        binaries+=("$bin")
    done <"$SIGNED_LOG"

    for bin in "${binaries[@]}"; do
        if [ -f "$bin" ]; then
            sign_binary "$bin"
            ((count++)) || true
        else
            log_warn "Skipping missing binary: $bin"
            ((skipped++)) || true
        fi
    done

    log_success "Refreshed ${count} binary(ies), skipped ${skipped}"
}

do_setup() {
    print_heading "TCC signing identity setup"
    ensure_identity
}

do_check() {
    local binary="${1:-}"
    [ -n "$binary" ] || fail "Usage: tcc-sign.sh check <binary>"
    local resolved
    resolved=$(readlink -f "$binary") || fail "Cannot resolve path: $binary"
    codesign -dvv "$resolved" 2>&1
}

do_list() {
    if [ ! -f "$SIGNED_LOG" ]; then
        log_info "No binaries signed yet."
        return 0
    fi
    print_heading "Signed binaries"
    while IFS= read -r bin; do
        if [ -f "$bin" ]; then
            local sig
            sig=$(codesign -dvv "$bin" 2>&1 | grep "Authority=" | head -1)
            log_info "$bin  ($sig)"
        else
            log_warn "$bin  (missing)"
        fi
    done <"$SIGNED_LOG"
}

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command> [args]

Sign ad-hoc binaries so macOS TCC / FDA grants persist across updates.

Commands:
    <binary>            Sign a single binary (resolves symlinks)
    refresh             Re-sign all previously signed binaries
    ensure-fda <binary> Check FDA and prompt to grant if missing
    setup               Create the signing identity only
    check <binary>      Show current signature of a binary
    list                List all previously signed binaries
    help                Show this help message (also: -h, --help)

Workflow:
    1. First run creates a "TCC Local Signer" certificate in your keychain
    2. Sign binaries that need FDA grants (e.g., uvx, python)
    3. Run 'ensure-fda' to check/prompt for FDA in System Settings
    4. After updates (e.g., uv self update), run 'refresh' to re-sign
EOF
}

# ── main ─────────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
    refresh)
        do_refresh
        ;;
    setup)
        do_setup
        ;;
    ensure-fda)
        shift
        do_ensure_fda "$@"
        ;;
    check)
        shift
        do_check "$@"
        ;;
    list)
        do_list
        ;;
    help | --help | -h | "")
        show_help
        ;;
    -*)
        fail "Unknown option: $1"
        ;;
    *)
        do_sign "$1"
        ;;
    esac
}

main "$@"
