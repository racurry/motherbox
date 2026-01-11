# WezTerm

GPU-accelerated terminal emulator with Lua configuration and built-in multiplexing.

## Installation

```bash
brew install --cask wezterm
```

Also install the configured font:

```bash
brew install --cask font-fira-code-nerd-font
```

## Setup

```bash
./apps/wezterm/wezterm.sh setup
```

This symlinks `wezterm.lua` to `~/.config/wezterm/`.


## Syncing Preferences

Repo sync. Config symlinked to `~/.config/wezterm/`.

Changes to `wezterm.lua` hot-reload automatically without restarting.

## References

- [Official Documentation](https://wezterm.org/)
- [Configuration Reference](https://wezterm.org/config/lua/config/index.html)
- [Color Schemes](https://wezfurlong.org/wezterm/colorschemes/)
