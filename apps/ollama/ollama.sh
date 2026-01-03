#!/bin/bash
# Ollama - Local LLM runner
# Installs Ollama and pulls recommended models

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bash/common.sh
source "${SCRIPT_DIR}/../../lib/bash/common.sh"

# Default models to pull during setup
# These are general-purpose models that work well on most hardware
# Edit this list or use 'ollama pull <model>' for additional models
DEFAULT_MODELS=(
    "llama3.2:3b" # Small, fast model for quick tasks (2GB)
)

# Optional larger models (uncomment or add as needed):
# "llama3.3:70b"      # State-of-the-art, requires 40GB+ RAM
# "mistral:7b"        # Fast and accurate general purpose
# "codellama:7b"      # Code generation and completion
# "deepseek-coder:6.7b"  # Strong coding model
# "qwen2.5-coder:7b"  # Excellent for coding tasks

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command> [OPTIONS]

Manage Ollama local LLM server.

COMMANDS:
    setup       Install Ollama and pull default models
    models      List installed models
    pull        Pull a specific model (e.g., ./ollama.sh pull mistral:7b)
    serve       Start Ollama server manually (foreground)
    status      Show Ollama service status
    help        Show this help message

OPTIONS:
    -h, --help  Show this help message

ENVIRONMENT VARIABLES (set in ~/.local.zshrc):
    OLLAMA_HOST           Bind address (default: 127.0.0.1:11434)
    OLLAMA_MODELS         Model storage directory (default: ~/.ollama/models)
    OLLAMA_KEEP_ALIVE     How long models stay loaded (default: 5m)
    OLLAMA_FLASH_ATTENTION Enable flash attention (set to 1)
    OLLAMA_NUM_PARALLEL   Parallel requests per model (default: auto)

NOTES:
    - Ollama runs as a menubar app (starts server automatically)
    - Models are stored in ~/.ollama/models/
    - API available at http://localhost:11434
EOF
}

do_setup() {
    print_heading "Setting up Ollama"

    # Install via Homebrew (cask)
    ensure_brew_package ollama ollama cask

    # Start Ollama (opens the app which runs its server)
    log_info "Starting Ollama..."
    if curl -s http://localhost:11434/api/version &>/dev/null; then
        log_info "Ollama server already running"
    else
        # Open the Ollama app which starts the server in the background
        open -a Ollama
        # Wait for server to be ready
        log_info "Waiting for Ollama server to start..."
        for i in {1..10}; do
            if curl -s http://localhost:11434/api/version &>/dev/null; then
                break
            fi
            sleep 1
        done
        if curl -s http://localhost:11434/api/version &>/dev/null; then
            log_success "Ollama server started"
        else
            log_warn "Server may still be starting, continuing..."
        fi
    fi

    # Pull default models
    print_heading "Pulling default models"
    for model in "${DEFAULT_MODELS[@]}"; do
        log_info "Pulling ${model}..."
        if ollama pull "${model}"; then
            log_success "Pulled ${model}"
        else
            log_warn "Failed to pull ${model}"
        fi
    done

    log_success "Ollama setup complete"
    echo ""
    log_info "Ollama API available at http://localhost:11434"
    log_info "Pull more models with: ollama pull <model>"
    log_info "List models with: ollama list"
}

do_models() {
    print_heading "Installed Ollama models"
    if command -v ollama &>/dev/null; then
        ollama list
    else
        log_error "Ollama not installed"
        exit 1
    fi
}

do_pull() {
    local model="${1:-}"
    if [[ -z "${model}" ]]; then
        log_error "No model specified"
        log_info "Usage: $(basename "$0") pull <model>"
        log_info "Examples: ollama pull mistral:7b, ollama pull codellama:7b"
        exit 1
    fi
    ollama pull "${model}"
}

do_serve() {
    print_heading "Starting Ollama server (foreground)"
    log_info "Press Ctrl+C to stop"
    log_info "API will be available at http://localhost:11434"
    echo ""
    # Note: This runs in foreground, blocking the terminal
    # Homebrew service recommended for normal use
    OLLAMA_FLASH_ATTENTION="${OLLAMA_FLASH_ATTENTION:-1}" \
        OLLAMA_KV_CACHE_TYPE="${OLLAMA_KV_CACHE_TYPE:-q8_0}" \
        ollama serve
}

do_status() {
    print_heading "Ollama Status"

    # Check if installed
    if ! command -v ollama &>/dev/null; then
        log_error "Ollama not installed"
        exit 1
    fi

    # Show version
    echo "Version: $(ollama --version 2>/dev/null || echo 'unknown')"
    echo ""

    # Check if app is running
    echo "App status:"
    if pgrep -x "Ollama" &>/dev/null; then
        log_success "Ollama app is running"
    else
        log_warn "Ollama app not running (start with: open -a Ollama)"
    fi
    echo ""

    # Check if server is responding
    echo "Server status:"
    if curl -s http://localhost:11434/api/version &>/dev/null; then
        log_success "Server responding at http://localhost:11434"
        echo "  Version: $(curl -s http://localhost:11434/api/version 2>/dev/null)"
    else
        log_warn "Server not responding"
    fi
    echo ""

    # List models
    echo "Installed models:"
    ollama list 2>/dev/null || echo "  (unable to list)"
}

main() {
    local command=""
    local extra_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
        help | --help | -h)
            show_help
            exit 0
            ;;
        setup | models | pull | serve | status)
            command="$1"
            shift
            # Capture remaining args for commands that need them
            extra_args=("$@")
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
        do_setup
        ;;
    models)
        do_models
        ;;
    pull)
        do_pull "${extra_args[0]:-}"
        ;;
    serve)
        do_serve
        ;;
    status)
        do_status
        ;;
    "")
        show_help
        exit 0
        ;;
    esac
}

main "$@"
