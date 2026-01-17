#!/usr/bin/env bash
# OpenSCAD setup and configuration script
# Sets up OpenSCAD with VS Code integration for 3D modeling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
OPENSCAD_LIBRARIES="$HOME/OpenSCAD/Libraries"
RECOMMENDED_EXTENSIONS=(
    "antyos.openscad"                    # Syntax highlighting, preview in external OpenSCAD
    "Leathong.openscad-language-support" # Language server with inline preview
)

# Discover OpenSCAD installation
discover_openscad_app() {
    local app
    app=$(find /Applications -maxdepth 1 -name "OpenSCAD*.app" -print -quit 2>/dev/null)
    if [[ -z "${app}" ]]; then
        return 1
    fi
    echo "${app}"
}

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Set up OpenSCAD with VS Code integration for 3D modeling.

Commands:
    setup       Run full setup (primary entry point)
    help        Show this help message (also: -h, --help)

Options for setup:
    --install               Install OpenSCAD and Rosetta 2 if not present
    --install-extensions    Install recommended VS Code extensions
    --test                  Run a test render after setup
    --skip-config           Skip VS Code configuration
EOF
}

install_rosetta() {
    log_info "Installing Rosetta 2..."

    if check_rosetta; then
        log_success "Rosetta 2 is already installed"
        return 0
    fi

    log_info "Installing Rosetta 2 (this may take a few minutes)..."
    if softwareupdate --install-rosetta --agree-to-license; then
        log_success "Rosetta 2 installed successfully"
    else
        log_error "Failed to install Rosetta 2"
        return 1
    fi
}

verify_rosetta() {
    log_info "Checking Rosetta 2 installation..."

    if check_rosetta; then
        log_success "Rosetta 2 is installed"
    else
        log_warn "Rosetta 2 is not installed. OpenSCAD requires Rosetta 2 on Apple Silicon."
        log_info "Install with: softwareupdate --install-rosetta --agree-to-license"
        return 1
    fi
}

install_openscad() {
    log_info "Installing OpenSCAD..."

    require_command brew

    if brew list --cask openscad &>/dev/null; then
        log_success "OpenSCAD is already installed"
        return 0
    fi

    log_info "Installing OpenSCAD via Homebrew..."
    if brew install --cask openscad; then
        log_success "OpenSCAD installed successfully"
    else
        log_error "Failed to install OpenSCAD"
        return 1
    fi
}

install_bosl2() {
    log_info "Installing BOSL2 library..."

    local bosl2_dir="${OPENSCAD_LIBRARIES}/BOSL2"

    # Create libraries directory if needed
    if [[ ! -d "${OPENSCAD_LIBRARIES}" ]]; then
        log_info "Creating OpenSCAD libraries directory: ${OPENSCAD_LIBRARIES}"
        mkdir -p "${OPENSCAD_LIBRARIES}"
    fi

    # Check if BOSL2 is already installed
    if [[ -d "${bosl2_dir}" ]]; then
        log_info "BOSL2 already installed, updating..."
        if git -C "${bosl2_dir}" pull --quiet; then
            log_success "BOSL2 updated successfully"
        else
            log_warn "Failed to update BOSL2, continuing with existing version"
        fi
        return 0
    fi

    # Clone BOSL2
    log_info "Cloning BOSL2 from GitHub..."
    if git clone --quiet https://github.com/BelfrySCAD/BOSL2.git "${bosl2_dir}"; then
        log_success "BOSL2 installed to ${bosl2_dir}"
    else
        log_error "Failed to clone BOSL2"
        return 1
    fi
}

verify_openscad() {
    local openscad_app="$1"
    local openscad_binary="$2"

    log_info "Verifying OpenSCAD installation..."

    if [[ -z "${openscad_app}" ]]; then
        log_error "OpenSCAD not found in /Applications"
        log_info "Install with: brew install --cask openscad"
        fail "OpenSCAD installation required"
    fi

    require_directory "${openscad_app}"
    require_file "${openscad_binary}"
    require_command openscad

    local version
    version=$(openscad --version 2>&1 | head -1)
    log_success "OpenSCAD found: ${version}"
}

check_vscode_extension() {
    local ext_id="$1"
    code --list-extensions | grep -q "^${ext_id}$"
}

install_extensions() {
    log_info "Installing recommended VS Code extensions..."

    for ext in "${RECOMMENDED_EXTENSIONS[@]}"; do
        if check_vscode_extension "${ext}"; then
            log_success "Extension already installed: ${ext}"
        else
            log_info "Installing extension: ${ext}"
            if code --install-extension "${ext}" &>/dev/null; then
                log_success "Installed: ${ext}"
            else
                log_warn "Failed to install: ${ext}"
            fi
        fi
    done
}

configure_vscode() {
    local openscad_binary="$1"

    log_info "Configuring VS Code settings for OpenSCAD..."

    # Backup existing settings before modification
    backup_file "${VSCODE_SETTINGS}" "openscad"

    local update_script="${SCRIPT_DIR}/update_vscode_settings.py"

    if "${update_script}" "${VSCODE_SETTINGS}" "${openscad_binary}"; then
        log_success "VS Code settings configured"
    else
        log_error "Failed to update VS Code settings"
        return 1
    fi

    log_info "Configuration added:"
    log_info "  - openscad.launchPath: ${openscad_binary}"
    log_info "  - scad-lsp.launchPath: ${openscad_binary}"
    log_info "  - scad-lsp.inlinePreview: true"
}

test_setup() {
    log_info "Testing OpenSCAD setup..."

    local example_file="${REPO_ROOT}/apps/openscad/example.scad"
    local test_dir
    test_dir=$(mktemp -d)
    local output_file="${test_dir}/test.stl"

    # Verify example file exists
    require_file "${example_file}"

    # Test command-line rendering
    log_info "Testing command-line rendering with example file..."
    if openscad -o "${output_file}" "${example_file}" 2>&1; then
        if [[ -f "${output_file}" ]]; then
            log_success "Command-line rendering works!"
            log_info "Rendered: ${output_file}"
            ls -lh "${output_file}"
        else
            log_error "Rendering completed but output file not created"
            rm -rf "${test_dir}"
            return 1
        fi
    else
        log_error "Command-line rendering failed"
        rm -rf "${test_dir}"
        return 1
    fi

    # Optionally open in VS Code
    log_info "To test VS Code integration:"
    log_info "  1. Open: code ${example_file}"
    log_info "  2. Click 'Preview in OpenSCAD' button (top right)"
    log_info "  3. Edit parameters and save - preview auto-reloads"

    echo ""
    read -p "Open example file in VS Code now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        code "${example_file}"
    fi

    # Clean up
    rm -rf "${test_dir}"
}

print_summary() {
    log_success "OpenSCAD Setup Complete!"
    log_info "OpenSCAD: $(openscad --version 2>&1 | head -1)"
    log_info "Command-line tool: $(which openscad)"
}

do_setup() {
    local do_install=false
    local install_exts=false
    local run_test=false
    local skip_config=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
        --install)
            do_install=true
            shift
            ;;
        --install-extensions)
            install_exts=true
            shift
            ;;
        --test)
            run_test=true
            shift
            ;;
        --skip-config)
            skip_config=true
            shift
            ;;
        *)
            log_warn "Ignoring unknown argument: $1"
            shift
            ;;
        esac
    done

    print_heading "OpenSCAD Setup"

    # Discover app paths
    local openscad_app openscad_binary
    openscad_app=$(discover_openscad_app) || true
    openscad_binary="${openscad_app}/Contents/MacOS/OpenSCAD"

    # Install if requested
    if [[ "${do_install}" == true ]]; then
        install_rosetta
        install_openscad
        openscad_app=$(discover_openscad_app)
        openscad_binary="${openscad_app}/Contents/MacOS/OpenSCAD"
    fi

    # Verify installation
    verify_openscad "${openscad_app}" "${openscad_binary}"
    verify_rosetta || true

    # Install BOSL2 library (always runs, updates if already installed)
    install_bosl2

    # Install extensions if requested
    if [[ "${install_exts}" == true ]]; then
        install_extensions
    fi

    # Configure VS Code
    if [[ "${skip_config}" == false ]]; then
        configure_vscode "${openscad_binary}"
    fi

    # Run test if requested
    if [[ "${run_test}" == true ]]; then
        test_setup
    fi

    print_summary "${openscad_binary}"
    log_success "OpenSCAD setup complete!"
}

main() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup)
            command="setup"
            shift
            break # Remaining args go to do_setup
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
        do_setup "$@"
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"
