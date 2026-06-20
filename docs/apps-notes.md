# App Helpers

## Airtable

Get an API token

1. Go to [Airtable Developer Hub](https://airtable.com/create/tokens)
2. Click **Create new token**
3. Name your token and select scopes:
   - `schema.bases:read` (required)
   - `data.records:read` (required)
   - `data.records:write` (optional, for write access)
4. Select which bases/workspaces the token can access
5. Copy the token (shown only once)

## Mailmate

Quit Mailmate.  Copy the custom keybindings file in.

```bash
cp mailmate/Motherbox.plist /Applications/MailMate.app/Contents/Resources/KeyBindings/
```

## Obsidian

Set up headless sync:

```bash
npm install -g obsidian-headless
ob login
ob sync-setup --vault {Vault name} --path ~/Notes/{Vault name}
```

## OpenSCAD

Install with Homebrew.  Libraries live in `~/OpenSCAD/Libraries`, which is on `$OPENSCADPATH` from zsh config. Install BOSL2 there when needed:

```bash
mkdir -p ~/OpenSCAD/Libraries
git clone https://github.com/BelfrySCAD/BOSL2.git ~/OpenSCAD/Libraries/BOSL2

git -C ~/OpenSCAD/Libraries/BOSL2 pull # update BOSL2
```

## Rayccast

Point the script command location to `scripts/apps/raycast/`

## Readwise

Unofficial "readwise-enhanced" API server adds more functionality than official one. Get API token from https://readwise.io/access_token

## Shottr

Make sure all of the default keyboard shortcuts are set up/turned off in macOS.  System Preferences > Keyboard > Shortcuts

![Keyboard Shortcuts](assets/macos_screenshot_settings.png)

1. Pull the license from 1Password and set it in Shottr.
2. Update Shottr settings:

![Shottr](assets/shottr_general.png)
![Shottr](assets/shottr_hotkeys.png)

## Stream deck

Configuration needs to be set up manually.  Export from old, import to new.

## VS Code

Complete these steps after installation:

1. **Enable Settings Sync** - Open Command Palette > "Settings Sync: Turn On" > Sign in with GitHub (not MS!)
2. **Wait for sync** - Extensions, settings, keybindings, and snippets will sync automatically
