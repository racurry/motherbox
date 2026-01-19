# ShortcutDetective

Detects which app receives a keyboard shortcut. Useful for diagnosing why a hotkey won't register in an app.

## Installation

```bash
brew install --cask shortcutdetective
```

## Setup

```bash
./apps/shortcutdetective/shortcutdetective.sh setup
```

This installs:

- Rosetta 2 (required on Apple Silicon)
- ShortcutDetective app

## Manual Setup

1. **Grant Accessibility permission** - When prompted on first launch, allow in System Settings > Privacy & Security > Accessibility

## Syncing Preferences

Not supported. No configuration to sync.

## Notes

- This app is deprecated upstream but still functional
- Intel-only binary, requires Rosetta 2 on Apple Silicon
- Cannot detect all keyboard shortcuts

## References

- [Irradiated Software Labs](https://www.irradiatedsoftware.com/labs/)
