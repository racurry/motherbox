# Homebrew

Package manager for macOS with Brewfile definitions.

## Contents

- `audit_apps.py` - Python script to audit installed applications
- `brew.sh` - Setup script for Homebrew and bundle installation
- `core.Brewfile` - Bootstrap formulae required before the rest of setup
- `Brewfile` - Main Brewfile with common packages
- `personal.Brewfile` - Personal machine packages
- `firsthand.Brewfile` - Firsthand work machine packages

## Setup

```bash
./apps/brew/brew.sh setup
```

This installs Homebrew if needed, installs core bootstrap packages, then runs
the common Brewfile and the active profile Brewfile.

Useful subcommands:

```bash
./apps/brew/brew.sh bootstrap
./apps/brew/brew.sh bundle --profile personal
./apps/brew/brew.sh audit
./apps/brew/brew.sh maintain
```
