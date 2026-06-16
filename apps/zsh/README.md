# Zsh

Zsh shell configuration.

## Installation

```bash
brew install chezmoi zsh
```

## Setup

```bash
./run/setup.sh
```

Mother Box configures chezmoi to use this repo, then applies the zsh rc files
from `home/`. Work-specific zsh fragments are rendered into `.zshrc` based on
the Mother Box profile.

## Contents

- `../../home/dot_zshrc.tmpl` - Main Zsh configuration template, rendered to
  `~/.zshrc`
- `../../home/.chezmoitemplates/firsthand.zsh.tmpl` - Firsthand shell fragment

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

Repo sync. `.zshrc` is managed by chezmoi for every profile. Work-specific
configuration is rendered directly into `.zshrc`.

## References

- [Zsh Documentation](https://zsh.sourceforge.io/Doc/)
