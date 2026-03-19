# Motherbox Configuration

This document describes the configuration system for storing persistent settings.

## Config File Location

```bash
~/.config/motherbox/config
```

The config file uses shell variable syntax (`KEY=value`) and is auto-created with
defaults when first accessed.

## Functions

All functions are defined in `lib/bash/common.sh`.

### `get_config`

```bash
get_config <key>
```

Retrieves a configuration value. Returns the value via stdout, or empty string
if not set.

```bash
retention="$(get_config BACKUP_RETENTION_DAYS)"
```

### `set_config`

```bash
set_config <key> <value>
```

Sets a configuration value. Creates the config file with defaults if it doesn't
exist.

```bash
set_config BACKUP_RETENTION_DAYS 90
```

## Available Config Keys

| Key                     | Default   | Description                            |
| ----------------------- | --------- | -------------------------------------- |
| `BACKUP_RETENTION_DAYS` | `60`      | Days to keep backups before pruning    |
| `PROFILE`               | *(empty)* | Set by `run/setup.sh` during execution |

## CLI Access

View and modify configuration via `./run/maintain.sh`:

```bash
./run/maintain.sh config                              # Show all values
./run/maintain.sh config get BACKUP_RETENTION_DAYS    # Get specific value
./run/maintain.sh config set BACKUP_RETENTION_DAYS 90 # Set value
```
