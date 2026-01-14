# Figma

Collaborative design tool for UI/UX design, prototyping, and design systems.

## Installation

```bash
brew install --cask figma
```

## Manual Setup

Complete these steps after installation:

1. **Sign in** - Launch Figma and sign in to your account
2. **Grant permissions** - Allow screen recording access if prompted (for presenting)
3. **Configure preferences** - Figma > Settings:
   - Theme (light/dark/system)
   - Color space (managed recommended)
   - Hardware acceleration

## Syncing Preferences

Native cloud sync via Figma account. All files, preferences, and settings sync automatically through Figma's servers.

Local settings are stored in `~/Library/Application Support/Figma/settings.json` but should not be synced as they contain machine-specific data (window positions, tab history, client ID).

## Enterprise/IT Configuration

For managed deployments, Figma supports plist-based configuration at `~/Library/Preferences/com.figma.Desktop.plist`:

| Key                  | Purpose                     |
| -------------------- | --------------------------- |
| `DisableUpdater`     | Prevent automatic updates   |
| `AllowedOriginHosts` | Whitelist external domains  |
| `ProxyUrl`           | Route traffic through proxy |

Most users do not need this.

## References

- [Guide to the Figma Desktop App](https://help.figma.com/hc/en-us/articles/5601429983767-Guide-to-the-Figma-desktop-app)
- [Deploy Figma on macOS](https://help.figma.com/hc/en-us/articles/1500012289622-Deploy-Figma-on-macOS)
- [Configure Desktop App via plist](https://help.figma.com/hc/en-us/articles/17719332934167-Configure-desktop-app-settings-via-a-property-list-on-macOS)
