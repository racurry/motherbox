# Steam

Video game digital distribution service from Valve.

## Installation

```bash
brew install --cask steam
```

Note: Requires Rosetta 2 on Apple Silicon Macs. Install with:

```bash
softwareupdate --install-rosetta --agree-to-license
```

## Setup

```bash
./apps/steam/steam.sh setup
```

This installs Steam and verifies Rosetta 2 is available.

## Manual Setup

Complete these steps after installation:

1. **Sign in** - Launch Steam and sign in to your Steam account
2. **Enable Steam Cloud** - Settings > Downloads + Cloud > Enable Steam Cloud
3. **Grant permissions** - Allow any requested permissions (accessibility, etc.)

## Syncing Preferences

Native cloud sync via Steam account. Game saves, settings, and library sync automatically through Valve's servers when Steam Cloud is enabled.

Local data is stored in `~/Library/Application Support/Steam/` but should not be synced externally.

## References

- [Steam Support](https://help.steampowered.com/)
- [Steam Cloud](https://help.steampowered.com/en/faqs/view/68D2-35AB-09A9-7678)
