# Codex CLI

AI coding agent from OpenAI that runs locally in your terminal.

## Installation

```bash
brew install --cask codex
```

## Setup

```bash
./apps/codex-cli/codex-cli.sh setup
```

This configures:

- Links `apps/_shared/AGENTS.global.md` to `~/AGENTS.md` (shared agent instructions)

After setup:

1. **Authentication** - Run codex and authenticate with your OpenAI account (requires ChatGPT Plus, Pro, Team, Edu, or Enterprise plan)

   ```bash
   codex
   ```

2. **Configure as needed** - Codex stores configuration in `~/.codex/config.toml` (optional)

### Subcommands

Run individual parts of setup:

- `rules` - link AGENTS.md only

## Syncing Preferences

Configuration files stored in `~/.codex/` contain API keys and personal data. Not suitable for syncing via this repo.

## References

- [Official Documentation](https://developers.openai.com/codex/)
- [GitHub Repository](https://github.com/openai/codex)
- [Quickstart Guide](https://developers.openai.com/codex/quickstart/)
