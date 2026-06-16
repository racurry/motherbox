# UV Global Tools

Manages Python CLI tools installed globally via `uv tool install`.

## Contents

- `uv.sh` - Setup script for installing and managing UV tools
- `uv-tools` - Main manifest of global tools to install
- `firsthand.uv-tools` - (optional) Firsthand work-specific tools
- `personal.uv-tools` - (optional) Personal machine-specific tools

## Setup

```bash
./apps/uv/uv.sh setup
```

## Commands

| Command | Description |
|---------|-------------|
| `setup` | Install all tools from uv-tools manifest(s) |
| `upgrade` | Upgrade all installed UV tools |
| `list` | Show tools from manifest vs installed |

## Manifest Format

```
# Comment lines start with #
tool "package[@version]" [--with dep1] [--with dep2] ...
```

Examples:

```
tool "ruff"
tool "black@24.0.0"
tool "mdformat" --with mdformat-gfm --with mdformat-frontmatter
```

## Why a custom manifest?

UV doesn't have a native manifest for global tools (like Brewfile). The `uv-tools` format provides:

- Declarative tool management
- Support for `--with` dependencies
- Version pinning
- Mode-specific tool lists (firsthand/personal)

## Notes

Individual tools may have their own `apps/*/` directories for configuration (e.g., `apps/mdformat/.mdformat.toml`). This manifest handles installation; app directories handle config.
