# KeyCastr

Open-source keystroke visualizer for screencasts and presentations.

## Installation

```bash
brew install --cask keycastr
```

## Setup

```bash
./apps/keycastr/keycastr.sh setup
```

This configures:

- Automatic updates enabled
- Menu bar icon visible
- Default visualizer selected

## Manual Setup

Complete these steps after installation:

1. **Launch KeyCastr** - Open from Applications
2. **Grant Input Monitoring permission** - When prompted, click "Open System Settings" and enable KeyCastr under Privacy & Security > Input Monitoring
3. **Position the overlay** - Click and drag the keystroke display to your preferred screen location
4. **Customize display** (optional) - Right-click the menu bar icon to access:
   - Display mode (command keys, all modified keys, or all keystrokes)
   - Mouse click visualization
   - Font size and colors
   - Fade duration

## Syncing Preferences

Not supported. Settings are stored locally in `~/Library/Preferences/io.github.keycastr.plist` and include window position which is machine-specific. Reconfigure manually on each machine.

## References

- [KeyCastr GitHub](https://github.com/keycastr/keycastr)
