# Git

Distributed version control with commit signing via 1Password.

## Installation

```bash
brew install git
```

Also install these for enhanced diff output:

```bash
brew install diff-so-fancy
```

## Setup

```bash
./apps/git/git.sh setup
```

This symlinks to `~/`:

- `.gitconfig` - Main configuration
- `.gitignore_global` - Global ignore patterns
- `.gitconfig_galileo` - Work-specific overrides (if present)

## Manual Setup

Complete these steps after running the setup script:

1. **Update user info** - Edit `.gitconfig` with your name and email
2. **Set up commit signing** - See [1Password SSH setup](../1password/README.md)
3. **Add SSH key to GitHub** - Settings > SSH and GPG keys > New SSH key (select "Signing Key" type for commit verification)

## Work/Personal Configuration

The config uses Git's `includeIf` to load different settings based on repository location:

```ini
[includeIf "gitdir:~/code/galileo/"]
  path = ~/.gitconfig_galileo
```

To add your own work config:

1. Create a new `.gitconfig_yourcompany` file with overrides
2. Add an `includeIf` block to `.gitconfig`
3. Update `git.sh` to symlink the new file

## Syncing Preferences

Repo sync. Config files symlinked to `~/`.

## References

- [Git Configuration](https://git-scm.com/docs/git-config)
- [Conditional Includes](https://git-scm.com/docs/git-config#_conditional_includes)
- [1Password SSH Signing](https://developer.1password.com/docs/ssh/)
