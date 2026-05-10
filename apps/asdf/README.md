# asdf

> ⚠️ Installed via Homebrew

Version manager for multiple runtime versions (Node.js, Python, Ruby, etc.).

## Contents

### Scripts

- `asdf.sh` - Setup script (run with `setup` command)

### Config Files (symlinked to ~/)

- `.tool-versions` - Global tool versions specification
- `.asdfrc` - asdf configuration (e.g., `legacy_version_file = yes`)
- `.default-gems` - Gems to auto-install with new Ruby versions
- `.default-python-packages` - pip packages to auto-install with new Python versions

## Setup

```bash
./apps/asdf/asdf.sh setup
```

This will:

1. Symlink all config files to `~/`
2. Add asdf plugins for each tool in `.tool-versions`
3. Install the specified runtime versions
