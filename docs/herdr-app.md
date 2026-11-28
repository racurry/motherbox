# Herdr app: layouts and mods

![Ya' Heard? With Perd](_assets/Ya_Heard_With_Perd.webp)

Motherbox's own [herdr-app](https://herdr.dev/) layout and mods. Herdr's guide for everything else is `~/.config/herdr-app/AGENTS.md`.

## What's here

All of it lives in [`home/dot_config/herdr-app/`](../home/dot_config/herdr-app/) and reaches `~/.config/herdr-app/` through `chezmoi apply`.

| Path | What it is |
|---|---|
| `layouts/ya-tabs.json` | The `ya-tabs` layout: Herdr's `main` with a tabbed sidebar and the mods below |
| `mods/ya-spaces/` | Spaces sidebar: every machine's spaces in one list, groups, per-repo icons and colors, a space menu, and the machines |
| `mods/ya-worktree/` | Worktrunk branch prompt and removal confirmation for the Spaces sidebar |
| `mods/ya-sidebar/` | The sidebar's tab strip, with a "needs you" pill while an agent is blocked, and the sidebar's commands |
| `mods/ya-status/` | Powerline status bar: agent, machine, folder, GitHub, git status, branch, git user |
| `mods/t3-inbox/` | Agents inbox, from [JinJieBeWater/herdr-t3-inbox](https://github.com/JinJieBeWater/herdr-t3-inbox) |
| `keys.json`, `settings.json`, `themes/` | Keys, personal settings, and themes |

Herdr writes the rest of its home itself: its shipped layouts and mods, `layouts/.state/`, `shared.json`, `ya-spaces.json`, and the `jsconfig.json` and `gpui-kit.d.ts` in each mod folder. Chezmoi leaves those alone.

## Changing a mod or the layout

1. Edit the files under `home/dot_config/herdr-app/`.
2. Check the mods: `scripts/apps/herdr-app/check-mods.sh [mod...]`. It checks the source folders, so it works before applying.
3. `chezmoi apply ~/.config/herdr-app`. Herdr reloads mods and layouts as the files land.
4. `herdr-app status` shows load errors, and `herdr-app shot <file>` takes a picture of the window.

Things to know:

- Chezmoi copies mod folders. Herdr doesn't hot-reload a symlinked mod folder, so they must stay real files.
- Chezmoi doesn't delete a file from `~/.config/herdr-app/mods/<name>/` when it leaves the source. Delete it there by hand too.
- Clicks in the window (sizes, shown and hidden blocks, the stack's shown child) are saved in `layouts/.state/`, not in the layout file. A field set in the layout file beats a click on it.
- Keep `layouts/ya-tabs.json` in the key order Herdr writes. `herdr-app do layout.set` rewrites the installed file in that order, and matching it keeps `chezmoi diff` quiet.
- `t3-inbox` is an unmodified copy of its upstream `mods/t3-inbox/` folder, apart from `"place": "none"` in its `mod.json` (so Herdr doesn't dock a second copy) and its test files being left out. Update it by copying the upstream folder over it.

## A second window

`scripts/apps/herdr-app/window.sh <layout>` opens a second Herdr window showing that layout, leaving the main window's layout alone. Both windows show the same spaces and agents.

A layout belongs to a Herdr home, so the window is a second Herdr process whose home is `~/.config/herdr-app-windows/layout-<layout>/`: a copy of the main home's mods, layouts, themes, keys and settings, made each time the window opens. Reach that window with `HERDR_APP_HOME=<its home> herdr-app …`.

## The `ya-tabs` layout

The sidebar is tabbed: a `stack` holding `ya-spaces` as a carousel and `t3-inbox`, under a block showing `ya-sidebar`. `ya-sidebar` draws one tab per stack child, named in its props. While any agent is blocked it also shows a "needs you" pill, which switches to the agents tab and focuses the most recently blocked agent.

| Key | Does |
|---|---|
| `cmd-alt-1` | Switch to Herdr's `main` layout |
| `cmd-alt-2` | Switch to `ya-tabs` |
| `cmd-shift-l` | Cycle through the layouts |
| `cmd-shift-b` | Switch between the spaces and agents tabs |
| `cmd-g` | Go to a group: type to narrow the groups, Enter to show one |
| `cmd-shift-g` | Show all groups |
| `cmd-alt-right`, `cmd-alt-left` | Next and previous stop of the group filter |
| `cmd-shift-f` | Search the spaces |

### Sidebar commands (`ya-sidebar`)

Bind these in `keys.json`. The palette (`cmd-k`) lists them under "Sidebar", from the `palette` entries in each mod's `mod.json`.

| Command | Does |
|---|---|
| `ya-sidebar.swap` | Show the sidebar's next tab |
| `ya-sidebar.find` | Show the spaces tab and put the cursor in its search field |
| `ya-sidebar.group-next`, `ya-sidebar.group-prev` | Show the spaces tab and move the group filter one stop: all groups, then each group |
| `ya-sidebar.group-all` | Show the spaces tab with all groups |
| `ya-sidebar.group-1` to `ya-sidebar.group-9` | Show the spaces tab with only that group, counted from the first |
| `mod.open:ya-spaces` | Open the group filter in the middle of the window |

A key reaches a mod only while it is on screen, and `ya-spaces` is off screen while the agents tab shows. `ya-sidebar` is always on screen, so it takes the command, shows the spaces tab, and passes the command to `ya-spaces` through the shared value `ya-spaces.do`. Add a sidebar command that `ya-spaces` should handle by adding it to `command()` in `ya-spaces/main.js`. `ya-sidebar` passes on any name it doesn't know.

The palette can't list one entry per group: `mod.json` is a fixed file and a mod command takes no arguments. "Go to group…" opens the group filter instead.

## Spaces sidebar (`ya-spaces`)

Forked from [jankeesvw/herdr-space-folders](https://github.com/jankeesvw/herdr-space-folders), itself Herdr's `spaces` mod.

**One list for every machine.** Spaces from this computer and from other machines sit in the same list, in any order. A space on another machine shows that machine's name after its own.

**Same repo, together.** A worktree sits under its checkout. A repo that is open on another machine too sits under this computer's space for it, showing just the machine's name. Rows under a space move with it and share its group.

**Worktrees on this Mac.** Use `wt go <branch>` or right-click a repo in the Spaces sidebar and choose **New worktree**. Worktrunk runs the user and project hooks, and an open Herdr App window opens or focuses the checkout under its main space. **Open worktree** shows a checkout that already exists.

Use `wt remove <branch>` or right-click a linked checkout and choose **Remove worktree**. Worktrunk runs its removal hooks and applies its branch deletion settings. Herdr closes the checkout's space when the checkout is gone. Worktrunk runs post-remove hooks in the background. Cleanup that needs the checkout or its terminals belongs in `pre-remove`.

The sidebar runs Worktrunk in a terminal tab so it can show approval prompts and errors. Worktree paths and user hooks live in [Worktrunk config](../home/dot_config/worktrunk/config.toml), and project hooks live in the project's `.config/wt.toml`. The user hooks call [`herdr-spaces.py`](../scripts/apps/worktrunk/herdr-spaces.py) to update the app.

**Order.** Drag a space onto another to put it next to it. The list keeps its own order.

**Groups.**

- To put a space in a group, drag it onto the group or onto a space in it, or right-click the space and pick the group.
- Click a group to fold or unfold it. Drag a group onto another to reorder them.
- Right-click a group to change its color or icon, edit it, or delete it.
- **Edit group…** sets "Start new spaces in", the folder the group's new spaces open in. `~` is the home folder of whichever machine the space is on.

**Carousel.** With props `{"carousel": true}`, as in `ya-tabs`, the header holds a search field, the group filter, a new-group button and a machines button.

- **Group filter.** The filter button opens a list of "All groups" and each group; type to narrow it, then click or press Enter. "All groups" shows every group with its spaces under it. A group shows that group alone, and the button shows its icon. While one group shows, every space is in a group: a space in none joins the group showing, and going to a space in another group shows that group.
- **Search.** Typing in the search field lists the matching spaces from every group, best match first. A space matches on its name, branch, repo or machine, and the letters only need to appear in order (`mbx` finds `motherbox`). Up and Down move through the results, Enter goes to the space, Escape clears the field.

**Machines.** The header's monitor button opens a popup listing this computer and the machines from `hc machine ls`. A connected machine's **+** opens a space there, a remote machine's gear opens Herdr's Settings → Machines, and **New machine** opens Herdr's `machine-add` dialog. Machines are added, renamed and removed in Herdr's own screens, never in the mod.

**Icons and colors.** Right-click a space and pick a color or **Set icon…**. An icon can be an emoji, one or two letters, or an image path. Every space in the same repo, worktrees included, shares the look, on any machine. A chosen color also shows in the tabs and agents list.

**State.** Everything is saved in one file on each computer, `~/.config/herdr-app/ya-spaces.json`. It holds space ids, so it stays out of chezmoi.

- `groups`: the groups, in order
- `of`: which space is in which group
- `order`: the list's order
- `page`: the group the carousel shows, or `"*"` for all groups
- `icons`: looks keyed by repo name, or by space name outside a repo, e.g. `{ "sadly.online": { "icon": "🌐", "color": "#22a99a" } }`. Image paths are absolute, from home (`~/logo.png`), or relative to `~/.config/herdr-app` (`icons/python.svg` uses Herdr's own program icons).

**Commands.** Bind these in `keys.json`. Herdr's own next and previous space keys follow Herdr's order, not the list's.

| Command | Does |
|---|---|
| `ya-spaces.next`, `ya-spaces.prev` | Step through the list as it's drawn |
| `ya-spaces.menu` | Open the shown space's menu |
| `ya-spaces.group-next`, `ya-spaces.group-prev`, `ya-spaces.group-all`, `ya-spaces.group-1` to `ya-spaces.group-9`, `ya-spaces.find` | The same as the `ya-sidebar` commands of those names, but only while the spaces tab shows |

The mod's overlays (group filter, group menu, machine menu, machines popup, group dialog, space menu, icon dialog) are modes of the same mod, picked by `props()`. Opened with no mode, as `mod.open` does, it is the group filter.

## Status bar (`ya-status`)

It follows the focused pane:

- **Agent:** what it is, its status, and how long it has been working.
- **Machine:** the computer the pane runs on.
- **Folder:** the repo name and the path inside it.
- **GitHub or git:** click the GitHub logo to open the repo.
- **Git status:** `↑`/`↓` ahead/behind, `●` staged, `○` unstaged or untracked, `⚠` no upstream.
- **Branch and git user:** the branch, then the `user.name` commits there are made as.

The right end counts agents that need you, are done or are working, then shows the palette key.

Icons are drawn with an installed Nerd Font (FiraCode Nerd Font here), falling back to Herdr's own icons.
