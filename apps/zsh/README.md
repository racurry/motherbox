# Zsh

Zsh shell configuration.

## Installation

```bash
brew install zsh
```

## Setup

```bash
./apps/zsh/zsh.sh setup
```

This symlinks `.zshrc` to `~/`.

## Contents

- `.zshrc` - Main Zsh configuration file
- `.galileorc` - Work-specific shell configuration (sourced if present)

## Local Configuration

Local secrets live in `~/.zshenv`. Zsh loads this file automatically on every
shell invocation (interactive, login, and scripts) — no `source` needed.

Use it for:

- API tokens and secrets
- Anything sensitive that shouldn't be committed

Create it manually:

```bash
touch ~/.zshenv
```

Example contents:

```bash
export AIRTABLE_API_TOKEN="pat..."
export OPENAI_API_KEY="sk-..."
```

This file is **not tracked in git** and should never be committed.

> Keep `.zshenv` to env-var exports only. It runs for every zsh invocation
> (including non-interactive scripts), so aliases, prompts, and other
> interactive-only setup belong in `.zshrc`.

Non-secret environment variables that can be committed belong in the managed
`.zshrc`.

## Syncing Preferences

Repo sync. `.zshrc`, `.galileorc`, and `.firsthandrc` are symlinked to `~/`.

## References

- [Zsh Documentation](https://zsh.sourceforge.io/Doc/)
