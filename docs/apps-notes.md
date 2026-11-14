# App Helpers

## 1Password SSH agent

SSH uses the 1Password agent at `~/.1password/agent.sock`, a link to the
1Password socket. `~/.ssh/config` sets it with `IdentityAgent`. Tools that read
`SSH_AUTH_SOCK` instead get the same socket from `~/.zshenv` in shells and from
the `net.aaroncurry.motherbox.ssh-auth-sock` LaunchAgent in GUI apps. That job
runs `launchctl setenv` at login, so an app sees it after it is relaunched.
Check with:

```sh
launchctl getenv SSH_AUTH_SOCK
ssh-add -l
```

`~/.ssh/config` also includes `~/.ssh/1Password/config`, which 1Password
generates from its SSH bookmarks. It pins each bookmarked host to one key, so
SSH offers that key alone instead of trying every key in the agent.

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

## Codex

`chezmoi apply` configures Codex after installing the CLI. The managed values
live in `home/.chezmoiscripts/run_onchange_after_46-codex.sh.tmpl`:

- Desktop worktree root: `~/.worktrees/codex`.
- Git and GitHub CLI identity: the agent account on `personal` machines.

The hook calls `scripts/apps/codex/configure.py`, which
uses Codex's [configuration API](https://learn.chatgpt.com/docs/app-server#config-rpc-examples-for-app-settings)
to update individual keys; Codex retains control of the rest of
`~/.codex/config.toml`. The hook reruns when its values or the Python script
change. Start a new Codex session after applying settings.

## Grok

`chezmoi apply` sets the same Git and GitHub CLI identity for Grok on
`personal` machines. The values live in
`home/.chezmoiscripts/run_onchange_after_47-grok.sh.tmpl`. The hook calls
`scripts/apps/grok/configure.py`, which writes those keys into
`~/.grok/config.toml` and leaves every other setting in place. On any other
profile it removes the keys. The hook reruns when its values or the Python
script change. Start a new Grok session after applying settings.

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

## GitHub agent identity

On `personal`-profile machines, Claude Code, Codex, and Grok shell commands
act as a separate agent GitHub account: commits, pushes, PRs, and comments
belong to it. A normal terminal acts as `racurry`. On the `firsthand`
profile, agents act as the work account.

The agent account is `despairbots`. Its name and noreply email are defined in
`home/dot_config/git/config_agent`. This file only takes effect when selected
by `GIT_CONFIG_GLOBAL` or explicitly included by another Git config.

Two environment variables in Claude's settings and in Codex and Grok's
`shell_environment_policy.set` do this:

- `GIT_CONFIG_GLOBAL` loads `~/.config/git/config_agent`, which sets the
  agent's name and email, turns signing off, and sends GitHub traffic over
  HTTPS with `gh` as the credential helper.
- `GH_CONFIG_DIR` points `gh` at `~/.config/gh-agent`, where the agent account
  is the only login.

Each machine needs the agent account signed in once. Use a browser session
where that account is signed in to GitHub:

```sh
GH_CONFIG_DIR=~/.config/gh-agent gh auth login --hostname github.com --git-protocol https --web
```

The agent account can only reach repositories where it is a collaborator.
Check both identities with:

```sh
gh api user --jq .login                                    # racurry
GH_CONFIG_DIR=~/.config/gh-agent gh api user --jq .login   # the agent account
```

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

## Orca

In **Settings → General → Workspace**:

- Set **Workspace Directory** to the absolute path of `~/.worktrees`
  (for example, `/Users/aaron/.worktrees`).
- Enable **Nest Workspaces**.

New worktrees use `~/.worktrees/<repo>/<workspace-name>`. Leave per-project
worktree location overrides empty to inherit the global directory.

The CLI's `orca project setup-update --worktree-base-path` sets a
per-project host setup override; it does not set the global default.

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

## TextEdit

Make new documents plain text instead of rich text:

```sh
scripts/apps/textedit/plain-text.sh
```

TextEdit keeps its preferences inside its app container, which macOS only
lets a terminal modify once that terminal has Full Disk Access. Grant it in
**System Settings → Privacy & Security → Full Disk Access**, relaunch the
terminal, then run the script. `mother setup` does not run it.

## VS Code

Complete these steps after installation:

1. **Enable Settings Sync** - Open Command Palette > "Settings Sync: Turn On" > Sign in with GitHub (not MS!)
2. **Wait for sync** - Extensions, settings, keybindings, and snippets will sync automatically
