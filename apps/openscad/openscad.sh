#!/usr/bin/env bash
# OpenSCAD setup and configuration script
# Sets up OpenSCAD CLI and BOSL2 library for 3D modeling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

OPENSCAD_LIBRARIES="$HOME/OpenSCAD/Libraries"

# Discover OpenSCAD installation
discover_openscad_app() {
    local app
    app=$(find /Applications -maxdepth 1 -name "OpenSCAD*.app" -print -quit 2>/dev/null)
    if [[ -z "${app}" ]]; then
        return 1
    fi
    echo "${app}"
}

# Find the binary inside an OpenSCAD app bundle
discover_openscad_binary() {
    local app="$1"
    local macos_dir="${app}/Contents/MacOS"
    local binary

    # Try common binary names
    for name in "OpenSCAD" "openscad" "openscad-studio"; do
        if [[ -x "${macos_dir}/${name}" ]]; then
            echo "${macos_dir}/${name}"
            return 0
        fi
    done

    # Fall back to first executable in MacOS dir
    binary=$(find "${macos_dir}" -maxdepth 1 -type f -perm +111 -print -quit 2>/dev/null)
    if [[ -n "${binary}" ]]; then
        echo "${binary}"
        return 0
    fi

    return 1
}

show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

Set up OpenSCAD with VS Code integration for 3D modeling.

Commands:
    setup       Run full setup (primary entry point)
    maintain    Update OpenSCAD and BOSL2 to latest versions
    help        Show this help message (also: -h, --help)

Options for setup:
    --install    Install OpenSCAD and Rosetta 2 if not present
    --test       Run a test render after setup
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

test_setup() {
    log_info "Testing OpenSCAD setup..."

    local example_file="${REPO_ROOT}/apps/openscad/example.scad"
    local bosl2_example="${REPO_ROOT}/apps/openscad/example_bosl2.scad"
    local test_dir
    test_dir=$(mktemp -d)
    local output_file="${test_dir}/test.stl"
    local bosl2_output="${test_dir}/test_bosl2.stl"

    # Verify example file exists
    require_file "${example_file}"

    # Test basic command-line rendering
    log_info "Testing basic OpenSCAD rendering..."
    if openscad -o "${output_file}" "${example_file}" 2>&1; then
        if [[ -f "${output_file}" ]]; then
            log_success "Basic rendering works!"
            ls -lh "${output_file}"
        else
            log_error "Rendering completed but output file not created"
            rm -rf "${test_dir}"
            return 1
        fi
    else
        log_error "Basic rendering failed"
        rm -rf "${test_dir}"
        return 1
    fi

    # Test BOSL2 rendering
    if [[ -d "${OPENSCAD_LIBRARIES}/BOSL2" ]]; then
        log_info "Testing BOSL2 library rendering..."
        require_file "${bosl2_example}"

        if openscad -o "${bosl2_output}" "${bosl2_example}" 2>&1; then
            if [[ -f "${bosl2_output}" ]]; then
                log_success "BOSL2 rendering works!"
                ls -lh "${bosl2_output}"
            else
                log_error "BOSL2 rendering completed but output file not created"
                rm -rf "${test_dir}"
                return 1
            fi
        else
            log_error "BOSL2 rendering failed - library may not be installed correctly"
            rm -rf "${test_dir}"
            return 1
        fi
    else
        log_warn "BOSL2 not installed, skipping BOSL2 test"
    fi

    # Clean up
    rm -rf "${test_dir}"
    log_success "All tests passed!"
}

print_summary() {
    log_info "OpenSCAD: $(openscad --version 2>&1 | head -1)"
    log_info "CLI: $(which openscad)"
    if [[ -d "${OPENSCAD_LIBRARIES}/BOSL2" ]]; then
        log_info "BOSL2: ${OPENSCAD_LIBRARIES}/BOSL2"
    fi
}

do_setup() {
    local do_install=false
    local run_test=false

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
        --install)
            do_install=true
            shift
            ;;
        --test)
            run_test=true
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
    openscad_binary=$(discover_openscad_binary "${openscad_app}") || true

    # Install if requested
    if [[ "${do_install}" == true ]]; then
        install_rosetta
        install_openscad
        openscad_app=$(discover_openscad_app)
        openscad_binary=$(discover_openscad_binary "${openscad_app}")
    fi

    # Verify installation
    verify_openscad "${openscad_app}" "${openscad_binary}"
    verify_rosetta || true

    # Install BOSL2 library (always runs, updates if already installed)
    install_bosl2

    # Run test if requested
    if [[ "${run_test}" == true ]]; then
        test_setup
    fi

    print_summary
    log_success "OpenSCAD setup complete!"
}

do_maintain() {
    print_heading "OpenSCAD Maintenance"

    local updated=false

    # Update OpenSCAD via Homebrew
    log_info "Checking for OpenSCAD updates..."
    if brew list --cask openscad &>/dev/null; then
        if brew upgrade --cask openscad 2>&1 | grep -q "already installed"; then
            log_success "OpenSCAD is already up to date"
        else
            log_success "OpenSCAD updated"
            updated=true
        fi
    elif brew list --cask openscad-studio &>/dev/null; then
        if brew upgrade --cask openscad-studio 2>&1 | grep -q "already installed"; then
            log_success "OpenSCAD Studio is already up to date"
        else
            log_success "OpenSCAD Studio updated"
            updated=true
        fi
    else
        log_warn "OpenSCAD not installed via Homebrew, skipping update"
    fi

    # Update BOSL2
    local bosl2_dir="${OPENSCAD_LIBRARIES}/BOSL2"
    if [[ -d "${bosl2_dir}/.git" ]]; then
        log_info "Updating BOSL2..."
        local before after
        before=$(git -C "${bosl2_dir}" rev-parse HEAD)
        if git -C "${bosl2_dir}" pull --quiet; then
            after=$(git -C "${bosl2_dir}" rev-parse HEAD)
            if [[ "${before}" == "${after}" ]]; then
                log_success "BOSL2 is already up to date"
            else
                log_success "BOSL2 updated ($(git -C "${bosl2_dir}" log --oneline "${before}..${after}" | wc -l | tr -d ' ') new commits)"
                updated=true
            fi
        else
            log_error "Failed to update BOSL2"
            return 1
        fi
    else
        log_warn "BOSL2 not installed, run 'setup' first"
    fi

    if [[ "${updated}" == true ]]; then
        log_success "Maintenance complete - updates applied"
    else
        log_success "Maintenance complete - everything up to date"
    fi
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
        maintain)
            command="maintain"
            shift
            break
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
    maintain)
        do_maintain
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"
