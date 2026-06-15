# Config Backups

This document defines the backup strategy for user configuration files.

For copying or symlinking config files to user locations, see [copying_configs.md](copying_configs.md).

## Backup Location

```text
~/.config/motherbox/backups/{date}/{app_name}/{filename}.{timestamp}
```

**Example:**

```text
~/.config/motherbox/backups/
└── 20241130/
    ├── zsh/
    │   └── .zprofile.20241130_143022
    └── git/
        └── .gitconfig.20241130_143102
```

The date directory groups all backups from the same day together. Individual
files retain full timestamps in their names for uniqueness.

## Retention Policy

- **Retention period**: Configurable via `BACKUP_RETENTION_DAYS` (default: 60)
- **Pruning**: Opportunistic (runs automatically on each backup operation)
- **Manual pruning**: `./run/maintain.sh prune`

To change the retention period:

```bash
./run/maintain.sh config set BACKUP_RETENTION_DAYS 90
```

## `backup_file` Function

Defined in `lib/bash/common.sh`.

```bash
backup_file <file_path> <app_name>
```

- Moves file to backup location
- Triggers pruning of backups older than `BACKUP_RETENTION_DAYS`
- **app_name is REQUIRED**

This function is called automatically by `link_file` and `copy_file` when
replacing existing files. Direct use is rarely needed.

## Maintenance

```bash
./run/maintain.sh prune    # Prune old backups
./run/maintain.sh config   # View backup retention settings
```
