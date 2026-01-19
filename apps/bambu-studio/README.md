# Bambu Studio

3D printing slicer software from Bambu Lab for Bambu Lab printers.

## Installation

```bash
brew install --cask bambu-studio
```

## Setup

```bash
./apps/bambu-studio/bambu-studio.sh setup
```

This installs Bambu Studio if not already present.

## Manual Setup

Complete these steps after installation:

1. **Sign in** - Launch Bambu Studio and sign in to your Bambu Lab account
2. **Add printer** - Add your Bambu Lab printer(s) via the setup wizard
3. **Enable cloud sync** - Settings are synced via Bambu Cloud when logged in

## Syncing Preferences

Native cloud sync via Bambu Cloud account. Printer profiles, filament settings, and process presets sync automatically when logged in.

Local profile data is stored in `~/Library/Application Support/BambuStudio/` but should not be synced externally as it contains machine-specific settings.

## References

- [Bambu Studio Quick Start Guide](https://wiki.bambulab.com/en/software/bambu-studio/studio-quick-start)
- [Bambu Lab Download Page](https://bambulab.com/en/download/studio)
