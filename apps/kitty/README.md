# Kitty

GPU-accelerated terminal emulator with modern features like ligatures, image support, and scriptable configuration.

## Installation

```bash
brew install --cask kitty
```

**Font dependency:** The config uses FiraCode Nerd Font. Install via:

```bash
brew install --cask font-fira-code-nerd-font
```

## Setup

```bash
./apps/kitty/kitty.sh setup
```

This symlinks `kitty.conf` to `~/.config/kitty/`.

## Manual Setup

1. **Grant permissions** - On first launch, approve any macOS security prompts for accessibility access.

2. **Set as default terminal** (optional) - No system setting exists; just use Spotlight or Dock to launch kitty instead of Terminal.app.

## Configuration Highlights

The config in this repo includes:

- **Font**: FiraCode Nerd Font Mono at 17pt
- **Cursor**: Beam shape with 0.3s blink and cursor trail effect
- **Tab bar**: Powerline style at top, always visible
- **Layouts**: Splits and fat layouts enabled
- **Keyboard shortcuts**: Cmd+Shift as modifier (kitty_mod)
  - `Cmd+\` / `Cmd+-`: Vertical/horizontal split
  - `Cmd+T`: New tab
  - `Cmd+N`: New OS window
  - `Cmd+Shift+R`: Reload config
- **macOS tweaks**: Option-as-Alt enabled, quit-on-last-window enabled
- **Remote control**: Enabled via unix socket at `/tmp/kitty-socket`
- **Transparency**: 85% background opacity

Reload config without restarting: `Cmd+Shift+R` or send `SIGUSR1`.

## Syncing Preferences

Repo sync. Config symlinked to `~/.config/kitty/kitty.conf`.

Theme files (`*-theme.auto.conf`) for light/dark mode switching should be added separately if using auto-theme switching.

## References

- [Official Documentation](https://sw.kovidgoyal.net/kitty/)
- [Configuration Reference](https://sw.kovidgoyal.net/kitty/conf/)
- [Keyboard Shortcuts](https://sw.kovidgoyal.net/kitty/actions/)
