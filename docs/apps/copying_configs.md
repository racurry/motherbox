# Copying Configs

This document describes how to copy or symlink configuration files from the
repository to user locations.

Both functions automatically back up existing files before replacing them.
See [config_backups.md](config_backups.md) for backup details.

## Functions

All functions are defined in `lib/bash/common.sh`.

### `link_file`

```bash
link_file <source> <dest> <app_name>
```

Creates a symlink from source to destination. Use for apps that work with symlinks.

| Destination State | Behavior |
|-------------------|----------|
| Doesn't exist | Create symlink |
| Correct symlink | Skip (no-op) |
| Different symlink | Replace symlink (no backup) |
| Regular file | Backup file, create symlink |

- **app_name is REQUIRED**

### `copy_file`

```bash
copy_file <source> <dest> <app_name>
```

Copies source to destination. Use for apps that don't follow symlinks.

| Destination State | Behavior |
|-------------------|----------|
| Doesn't exist | Copy file |
| Symlink (any) | Remove symlink, copy file |
| Regular file | Backup file, copy file |

- **app_name is REQUIRED**
- Always copies (no content comparison)

## When to Use Each Function

| Scenario | Function |
|----------|----------|
| Config file, app follows symlinks | `link_file` |
| Config file, app needs real file | `copy_file` |

Most apps work fine with symlinks. Use `copy_file` only when you've confirmed
an app doesn't follow symlinks (e.g., some apps read config at startup and
don't re-resolve symlinks, or explicitly check for regular files).

## Examples

```bash
# Symlink a config file
link_file "${REPO_ROOT}/apps/git/.gitconfig" "${HOME}/.gitconfig" "git"

# Copy when symlinks aren't supported
copy_file "${REPO_ROOT}/apps/mailmate/Pumpkin.plist" "${target_plist}" "mailmate"
```
