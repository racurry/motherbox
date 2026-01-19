# Google Chrome

Web browser by Google.

## Installation

```bash
brew install --cask google-chrome
```

## Setup

```bash
./apps/chrome/chrome.sh setup
```

This installs Google Chrome if not already present.

## Manual Setup

Complete these steps after installation:

1. **Sign in** - Launch Chrome and sign in to your Google account
2. **Enable sync** - Settings > You and Google > Turn on sync
3. **Grant permissions** - Allow any requested permissions (screen recording for casting, etc.)

## Syncing Preferences

Native cloud sync via Google account. All bookmarks, extensions, passwords, history, settings, and themes sync automatically through Google's servers.

Local profile data is stored in `~/Library/Application Support/Google/Chrome/` but should not be synced externally as it contains machine-specific caches and session data.

## References

- [Chrome Help](https://support.google.com/chrome/)
- [Sync Chrome across devices](https://support.google.com/chrome/answer/185277)
