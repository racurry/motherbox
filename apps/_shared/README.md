# Shared Configuration

This directory contains configuration files shared across multiple apps/tools.

## Contents

### AGENTS.global.md

Universal coding agent rules used by all AI coding assistants:

- Claude Code (`apps/claudecode/`)
- Codex CLI (`apps/codex-cli/`)
- Gemini CLI (`apps/gemini-cli/`)

**Symlinked to:** `~/AGENTS.md`

Contains environment-level rules about:

- Runtime management
- Project environments (direnv)
- Package management
- Git commit style
- Python/Node/Ruby conventions
- Secrets handling

## Usage

Individual app setup scripts (`apps/*/setup.sh` or `apps/*/*.sh`) create symlinks from this shared location to the appropriate target locations.

## Adding Shared Resources

Place new shared configuration here when:

- Multiple tools need identical configuration
- The configuration is environment-level, not tool-specific
- You want a single source of truth

Examples of good candidates:

- Shared coding standards
- Environment conventions
- Cross-tool workflows
