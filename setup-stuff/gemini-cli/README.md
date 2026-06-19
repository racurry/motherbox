# Gemini CLI

Google's AI coding assistant that brings Gemini models directly into your terminal.

## Installation

```bash
brew install gemini-cli
```

## Setup

```bash
./apps/gemini-cli/gemini-cli.sh setup
```

This configures:

- Links `apps/_shared/AGENTS.global.md` to `~/AGENTS.md` (shared agent instructions)

After setup:

1. **Authentication** - Run gemini and authenticate with your Google account (free tier available)

   ```bash
   gemini
   ```

2. **Configure as needed** - Gemini stores configuration in `~/.gemini/settings.json` (optional)

### Subcommands

Run individual parts of setup:

- `rules` - link AGENTS.md only

## Features

- Access to Gemini 2.5 Pro with 1M token context window
- Built-in tools: Google Search grounding, file operations, shell commands
- MCP (Model-Context Protocol) server support
- Free tier: 60 requests/min with personal Google account

## Syncing Preferences

Configuration files stored in `~/.gemini/` may contain credentials and personal data:

- **DO NOT sync**: `oauth_creds.json`, `google_accounts.json`, `state.json`, `.env`
- **Safe to sync**: `GEMINI.md` (if no secrets), `settings.json` (UI preferences only)

## References

- [Official Documentation](https://developers.google.com/gemini-code-assist/docs/gemini-cli)
- [GitHub Repository](https://github.com/google-gemini/gemini-cli)
- [Configuration Guide](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/configuration.md)
- [GEMINI.md Files Documentation](https://google-gemini.github.io/gemini-cli/docs/cli/gemini-md.html)
