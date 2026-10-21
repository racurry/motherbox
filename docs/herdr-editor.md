# TTT in herdr

Press **Cmd+;**, then **Shift+E**, to open and focus TTT in a new herdr tab.
The editor opens the active worktree directory, or the workspace directory
when no worktree is selected. Right-clicks go to TTT; right-click the pane frame
to access herdr's menu. Quitting TTT closes its pane.

The same action is available from the CLI:

```sh
herdr plugin action invoke motherbox.ttt.open
```

## Setup

With motherbox initialized on a Mac, run:

```sh
chezmoi apply
```

The apply hooks install TTT through Homebrew, Python through mise, and Herdr
through its native installer at `~/.local/bin/herdr`. Rustup supplies Cargo for
building the palette. The Herdr setup hook runs after those dependencies,
links `motherbox.ttt` to this computer's motherbox checkout, installs the palette
revision declared in `scripts/apps/herdr/setup.sh`. Both are enabled on a fresh
install; an existing palette's enabled/disabled preference is preserved.
It reloads running sessions without stopping panes and does not start a server
on a new machine. Run `herdr` to start using it.

The setup hook re-runs when its script, the TTT manifest/launcher, the Herdr
config, or the checkout path changes. Use the primary checkout for everyday
use. To repair plugin registration manually, run from that checkout:

```sh
scripts/utils/native-installs.sh herdr
scripts/apps/herdr/setup.sh
```

Herdr owns its binary updates through `herdr update`. To adopt a new palette
revision across machines, change `palette_ref` in the setup script and apply.
TTT follows the managed Brewfile. Plugin registries, session state, sockets,
builds, and logs are local runtime data, not chezmoi source files.

The plugin lives in `scripts/apps/herdr/editor/`; the shortcut lives in
`home/dot_config/herdr/config.toml`. Running `ttt` directly does not use the plugin.

## Command palette

**Cmd+K** opens the [Herdr Palette](https://github.com/ramarivera/herdr-palette).
Type to filter, press Enter to run a command, or Escape to close it. Ctrl+T
switches between tree and list views. Search for **Open TTT** to launch the editor.
Some built-in commands are shown only as shortcut references.

Ghostty forwards Cmd+K while using herdr shortcuts. In Ghostty's own shortcut
mode, Cmd+K clears the screen. Reload Ghostty's configuration with Cmd+Shift+,
after applying its config.
