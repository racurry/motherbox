# Ollama

Local LLM runner for running models like Llama, Mistral, and CodeLlama locally.

## Installation

```bash
brew install ollama
```

## Setup

```bash
./apps/ollama/ollama.sh setup
```

This:

- Installs Ollama via Homebrew
- Starts Ollama as a background service
- Pulls the default model (llama3.2:3b)

## Manual Setup

1. **Pull additional models** - Choose models based on your hardware:

   ```bash
   ollama pull mistral:7b      # General purpose (8GB RAM)
   ollama pull codellama:7b    # Code generation (8GB RAM)
   ollama pull llama3.3:70b    # Best quality (40GB+ RAM)
   ```

2. **Configure environment** (optional) - Add to `~/.local.zshrc`:

   ```bash
   export OLLAMA_KEEP_ALIVE="30m"     # Keep models loaded longer
   export OLLAMA_FLASH_ATTENTION=1    # Reduce memory usage
   export OLLAMA_NUM_PARALLEL=2       # Concurrent requests
   ```

## Usage

```bash
# Chat with a model
ollama run llama3.2

# List installed models
ollama list

# Pull a new model
ollama pull mistral:7b

# Check service status
./apps/ollama/ollama.sh status
```

## Service Management

Ollama runs as a background service via Homebrew:

```bash
brew services start ollama   # Start service
brew services stop ollama    # Stop service
brew services restart ollama # Restart after config changes
```

## Integrations

- **VS Code**: Use [Continue.dev](https://continue.dev) extension with Ollama as backend
- **Web UI**: [Open WebUI](https://github.com/open-webui/open-webui) provides a ChatGPT-like interface
- **API**: REST API at `http://localhost:11434` (OpenAI-compatible)

## Syncing Preferences

Not applicable. Ollama has no config files to sync. Configuration is via environment variables and models are stored locally in `~/.ollama/models/`.

## References

- [Ollama Documentation](https://ollama.com/)
- [Ollama FAQ](https://docs.ollama.com/faq)
- [Model Library](https://ollama.com/library)
- [GitHub Repository](https://github.com/ollama/ollama)
