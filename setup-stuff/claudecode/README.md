# Claude Code

Anthropic's CLI for Claude, providing AI assistance directly in your terminal.

## Installation

```bash
brew install claude-code
```

## Setup

```bash
./apps/claudecode/claudecode.sh setup
```

This configures:

- Links `CLAUDE.global.md` to `~/.claude/CLAUDE.md` (Claude-specific rules)
- Links `apps/_shared/AGENTS.global.md` to `~/AGENTS.md` (shared agent instructions)
- Syncs commands from `commands/` to `~/.claude/commands/` (individual symlinks)
- Enables extended thinking and project MCP servers in `settings.json`

### Subcommands

Run individual parts of setup:

- `rules` - link CLAUDE.md and AGENTS.md only
- `commands` - sync commands directory only
- `settings` - configure settings.json only

## Syncing Preferences

Repo sync. Global rules and commands are stored in this repo and symlinked to `~/.claude/`.

Commands are linked individually (not as a directory) so you can add local-only commands to `~/.claude/commands/` without tracking them in git.

## References

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
