# ScanSnap Home

Fujitsu scanner software for ScanSnap document scanners.

## Installation

```bash
brew install --cask fujitsu-scansnap-home
```

Requires Rosetta 2 on Apple Silicon Macs:

```bash
softwareupdate --install-rosetta --agree-to-license
```

## Setup

```bash
./apps/scansnap/scansnap.sh setup
```

This installs ScanSnap Home and verifies Rosetta 2 is available.

## Manual Setup

Complete these steps after installation:

1. **Connect scanner** - Connect your ScanSnap device via USB or Wi-Fi
2. **Launch app** - Open ScanSnap Home from Applications
3. **Register scanner** - Follow the setup wizard to register your device
4. **Configure profiles** - Create scan profiles for your common workflows
5. **Grant permissions** - Allow any requested permissions (Accessibility, etc.)

## Syncing Preferences

Manual export/import via app. Use ScanSnap Home > Edit > Import/Export profiles to save and restore scan profiles.

Profile files are OS-specific (macOS profiles cannot be imported on Windows and vice versa).

For cloud-based sync, configure ScanSnap Cloud in the app preferences.

## References

- [ScanSnap Home Help](https://www.pfu.ricoh.com/imaging/downloads/manual/ss_webhelp/en/help/webhelp/topic/ope_profile_import_export.html)
- [ScanSnap FAQ](https://scansnap-faq.pfu.ricoh.com/hc/en-us)
