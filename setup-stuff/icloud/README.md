# iCloud

iCloud Drive symlink management for dotfiles and configuration.

## Contents

- `icloud.sh` - Setup script for iCloud symlinks and configuration

## Setup

```bash
./apps/icloud/icloud.sh setup
```

Creates `~/iCloud` as a symlink to iCloud Drive when iCloud Drive is available.

## Diagnostics

```bash
./apps/icloud/icloud.sh diagnose
```

Runs local iCloud Drive checks for sync processes, status, logs, problem files,
permissions, and remediation tips.
