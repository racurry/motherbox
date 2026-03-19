#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

TCC_SIGN="${SCRIPT_DIR}/../../run/tcc-sign.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command> [OPTIONS]

Manage uv itself (standalone install) and global tools from a declarative
uv-tools manifest.

COMMANDS:
    setup       Install uv and all tools from uv-tools manifest(s)
    upgrade     Upgrade uv itself and all installed UV tools
    list        Show tools from manifest vs installed
    help        Show this help message

OPTIONS:
    --mode MODE   Set to 'galileo' or 'personal' to install mode-specific tools
                  from apps/uv/galileo.uv-tools or apps/uv/personal.uv-tools
                  in addition to the main apps/uv/uv-tools

MANIFEST FORMAT:
    # Comment lines start with #
    tool "package[@version]" [--with dep1] [--with dep2] ...

    Examples:
        tool "ruff"
        tool "black@24.0.0"
        tool "mdformat" --with mdformat-gfm --with mdformat-frontmatter
EOF
}

# parse_manifest reads a uv-tools manifest and outputs tool specs, one per line
# Each line: package[@version] [--with dep1] [--with dep2] ...
parse_manifest() {
    local manifest="$1"

    if [[ ! -f "${manifest}" ]]; then
        return 0
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip empty lines and comments
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

        # Match: tool "package" ... or tool 'package' ...
        if [[ "${line}" =~ ^[[:space:]]*tool[[:space:]]+[\"\']([^\"\']+)[\"\'](.*)$ ]]; then
            local package="${BASH_REMATCH[1]}"
            local rest="${BASH_REMATCH[2]}"
            echo "${package}${rest}"
        fi
    done <"${manifest}"
}

# install_tool installs a single tool from a spec line
# Input: package[@version] [--with dep1] [--with dep2] ...
install_tool() {
    local spec="$1"

    # Extract package name (without version) for checking if installed
    local package_with_version package_name
    package_with_version="${spec%% *}"
    package_name="${package_with_version%%@*}"

    # Check if already installed
    if uv tool list 2>/dev/null | grep -q "^${package_name} "; then
        log_info "${package_name} already installed"
        return 0
    fi

    log_info "Installing ${package_with_version}..."

    # Build the install command
    local cmd=(uv tool install)

    # Split spec into words, handling the package and --with flags
    local first=true
    for word in ${spec}; do
        if [[ "${first}" == "true" ]]; then
            cmd+=("${word}")
            first=false
        else
            cmd+=("${word}")
        fi
    done

    if "${cmd[@]}"; then
        log_success "Installed ${package_name}"
    else
        log_error "Failed to install ${package_name}"
        return 1
    fi
}

# install_from_manifest installs all tools from a uv-tools manifest
install_from_manifest() {
    local manifest="$1"

    if [[ ! -f "${manifest}" ]]; then
        log_warn "Manifest not found: ${manifest}"
        return 0
    fi

    log_info "Installing tools from ${manifest}"

    local failed=0
    while IFS= read -r spec; do
        [[ -z "${spec}" ]] && continue
        if ! install_tool "${spec}"; then
            ((failed++)) || true
        fi
    done < <(parse_manifest "${manifest}")

    if [[ ${failed} -gt 0 ]]; then
        log_warn "${failed} tool(s) failed to install"
        return 1
    fi
}

install_uv() {
    # In an ideal world, I would just install uv w/ brew. I am using locally running
    # mcp servers with Claude Desktop, (eg things-mcp).  Brew + uv + claude desktop cache 
    # results in ephemeral, unsigned binaries that macos just refuses to trust long term.
    # I end up having to approve uv's TCC permission every time Claude Desktop opens.
    #
    # To avoid doing this we install a stable uv binary directly, sign it ourselves, and then
    # I have to manually add it to Full Disk Access in macos system settings.
    # Hopefully someday this gets less dumb.

    if command -v uv >/dev/null 2>&1; then
        local uv_path
        uv_path="$(command -v uv)"
        log_info "uv already installed at ${uv_path}"
        return 0
    fi

    log_info "Installing uv via standalone installer..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    log_success "uv installed to ~/.local/bin/uv"

    log_info "Signing uv and uvx for TCC/FDA persistence..."
    "$TCC_SIGN" ~/.local/bin/uv
    "$TCC_SIGN" ~/.local/bin/uvx

    # Always show FDA instructions; only open System Settings interactively
    local fda_flags=()
    if [[ "${UNATTENDED:-false}" != "true" ]]; then
        fda_flags+=(--open)
    fi
    "$TCC_SIGN" ensure-fda "${fda_flags[@]}" ~/.local/bin/uvx
}

do_setup() {
    print_heading "Setup UV"

    install_uv
    require_command uv

    # Install from main manifest
    local main_manifest="${SCRIPT_DIR}/uv-tools"
    if [[ -f "${main_manifest}" ]]; then
        install_from_manifest "${main_manifest}"
    else
        log_warn "No main manifest found at ${main_manifest}"
    fi

    # Install mode-specific tools if mode is set
    if [[ -n "${SETUP_MODE:-}" ]]; then
        local mode_manifest="${SCRIPT_DIR}/${SETUP_MODE}.uv-tools"
        if [[ -f "${mode_manifest}" ]]; then
            log_info "Installing ${SETUP_MODE}-specific tools"
            install_from_manifest "${mode_manifest}"
        fi
    fi

    log_success "UV tools setup complete"
}

do_upgrade() {
    print_heading "Upgrade UV"

    require_command uv

    log_info "Upgrading uv itself..."
    uv self update
    "$TCC_SIGN" ~/.local/bin/uv
    "$TCC_SIGN" ~/.local/bin/uvx
    log_success "uv updated and re-signed"

    log_info "Upgrading all UV tools..."
    if uv tool upgrade --all; then
        log_success "All tools upgraded"
    else
        log_warn "Some tools may have failed to upgrade"
    fi
}

do_list() {
    print_heading "UV tools status"

    require_command uv

    echo ""
    echo "=== Installed tools ==="
    uv tool list 2>/dev/null || echo "(none)"

    echo ""
    echo "=== Tools in uv-tools ==="
    local main_manifest="${SCRIPT_DIR}/uv-tools"
    if [[ -f "${main_manifest}" ]]; then
        parse_manifest "${main_manifest}" | while read -r spec; do
            local pkg="${spec%% *}"
            echo "  ${pkg}"
        done
    else
        echo "(no uv-tools manifest found)"
    fi

    # Show mode-specific if SETUP_MODE is set
    if [[ -n "${SETUP_MODE:-}" ]]; then
        local mode_manifest="${SCRIPT_DIR}/${SETUP_MODE}.uv-tools"
        if [[ -f "${mode_manifest}" ]]; then
            echo ""
            echo "=== Tools in ${SETUP_MODE}.uv-tools ==="
            parse_manifest "${mode_manifest}" | while read -r spec; do
                local pkg="${spec%% *}"
                echo "  ${pkg}"
            done
        fi
    fi
}

main() {
    local command=""
    local args=("$@")

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --mode)
            shift 2
            ;;
        --unattended)
            shift
            ;;
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup | upgrade | list)
            command="$1"
            shift
            ;;
        *)
            # Check if it's a global flag from run/setup.sh
            if shift_count=$(check_global_flag "$@"); then
                shift "$shift_count"
            else
                log_warn "Ignoring unknown argument: $1"
                shift
            fi
            ;;
        esac
    done

    case "${command}" in
    setup)
        determine_setup_mode "${args[@]}" || true
        do_setup
        ;;
    upgrade)
        do_upgrade
        ;;
    list)
        determine_setup_mode "${args[@]}" || true
        do_list
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"
