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

## Game Mode

Motherbox forces Game Mode off at login using
`xcrun gamepolicyctl game-mode set off`. The user LaunchAgent
`net.aaroncurry.motherbox.game-mode-off` also runs when loaded by the chezmoi
hook. It retries failed commands no more often than every 30 seconds and
exits after success. Nightly maintenance reloads the job if it is missing
from launchd.

This requires full Xcode to be installed and selected with `xcode-select`.
Check the effective state and policy with:

```sh
xcrun gamepolicyctl game-mode status
launchctl print "gui/$(id -u)/net.aaroncurry.motherbox.game-mode-off"
```

Expect Game Mode to be off with a forced-off policy. A successful login job
has a last exit code of `0`; it does not need to remain running. Output and
errors are saved in `~/Library/Logs/motherbox-game-mode-off.log` and
`~/Library/Logs/motherbox-game-mode-off.error.log`.

The override is reported to reset at logout, which is why it is reapplied at
each login. This job does not poll for policy changes after a successful run.
To restore automatic policy for the current session:

```sh
xcrun gamepolicyctl game-mode set auto
```

The next login or explicit reload of the job will force it off again.

## Mail

Copy a `message://` deep link to the selected email. Logic: `scripts/utils/copy-mail-link.applescript` (also wired as a Raycast command).

Add a native right-click / Services entry via an Automator **Quick Action**:

1. Automator > New > **Quick Action**.
2. **Workflow receives** "no input" **in** Mail.app.
3. Add **Run Shell Script** (shell `/bin/zsh`):

   ```sh
   osascript "$HOME/.config/motherbox/scripts/utils/copy-mail-link.applescript"
   ```

4. Save as **Copy Mail Link** → shows in Mail's right-click menu and Mail ▸ Services.

Custom toolbar buttons aren't supported in Mail. For a hotkey, bind the Service via System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ App Shortcuts.

## Mailmate

Quit Mailmate. Copy the custom keybindings file in.

```bash
cp mailmate/Motherbox.plist /Applications/MailMate.app/Contents/Resources/KeyBindings/
```

## Obsidian

`obsidian-headless` is installed through the managed mise config. On the
personal Mac mini, it is the only process that connects `~/Notes/Memex` to
Obsidian Sync. The first Motherbox apply installs the CLI and loads the
LaunchAgent; it will retry until you complete the one-time login and vault
setup:

```bash
ob login
ob sync-setup --vault Memex --path ~/Notes/Memex
```

Motherbox starts `ob sync --continuous` at login and launchd keeps it running.
Obsidian Desktop may open the same folder, but disconnect its remote vault and
keep its Sync core plugin disabled on the Mini so only Headless Sync talks to
the remote vault.

## OpenSCAD

Install with Homebrew. Libraries live in `~/OpenSCAD/Libraries`, which is on `$OPENSCADPATH` from zsh config. Install BOSL2 there when needed:

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

Make sure all of the default keyboard shortcuts are set up/turned off in macOS. System Preferences > Keyboard > Shortcuts

![Keyboard Shortcuts](assets/macos_screenshot_settings.png)

1. Pull the license from 1Password and set it in Shottr.
2. Update Shottr settings:

![Shottr](assets/shottr_general.png)
![Shottr](assets/shottr_hotkeys.png)

## Stream deck

Configuration needs to be set up manually. Export from old, import to new.

## VS Code

Complete these steps after installation:

1. **Enable Settings Sync** - Open Command Palette > "Settings Sync: Turn On" > Sign in with GitHub (not MS!)
2. **Wait for sync** - Extensions, settings, keybindings, and snippets will sync automatically
