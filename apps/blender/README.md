# Blender

Free, open-source 3D creation suite — modeling, sculpting, animation, simulation, rendering, compositing, motion tracking, and video editing.

## Installation

```bash
brew install --cask blender
```

For the LTS track instead: `brew install --cask blender@lts`.

## Setup

```bash
./apps/blender/blender.sh setup
```

Installs Blender if not already present and prints the detected CLI path and existing config versions.

## Maintenance

```bash
./apps/blender/blender.sh maintain
```

Runs `brew upgrade --cask blender`.

## Manual Setup

After first launch:

1. **Settings migration** — If you have a previous major version's config, Blender prompts to copy it (`config/` and `scripts/`). Accept it once per new major version.
2. **Theme / keymap** — Edit → Preferences → Themes / Keymap. Export to a file if you want to track it.
3. **Asset libraries** — Preferences → File Paths → Asset Libraries. Keep these paths machine-agnostic (e.g. under `~/`) so configs sync cleanly.

## Directory Layout

Per-major-version config root: `~/Library/Application Support/Blender/<X.Y>/`

| Path                    | Holds                                                           |
| ----------------------- | --------------------------------------------------------------- |
| `config/userpref.blend` | All preferences (binary)                                        |
| `config/startup.blend`  | Default scene shown on launch (binary)                          |
| `scripts/addons/`       | Legacy addons (drop-in `.py` or package dirs)                   |
| `scripts/presets/`      | User-saved presets                                              |
| `scripts/startup/`      | Auto-run Python init scripts                                    |
| `extensions/<repo_id>/` | Extensions (4.2+) from `extensions.blender.org` and other repos |
| `extensions/.cache/`    | Download cache — do NOT sync                                    |
| `datafiles/`            | Studio lights, brushes, color management overrides              |

Cache lives separately at `~/Library/Caches/Blender/<X.Y>/`.

## Syncing Preferences

Each major version (e.g. `4.5/`, `5.1/`) is independent. Blender does not have native cloud sync.

**Safe to track / sync:**

- `scripts/addons/` and `scripts/presets/` — pure user content
- `scripts/startup/` — small Python init scripts
- Exported theme `.xml` (Preferences → Themes → Save)
- Exported keymap `.py` (Preferences → Keymap → Export)

**Track with caution (binary, churns):**

- `userpref.blend` — diffs poorly; can contain absolute paths (render output, scripts dir, asset libraries). If tracked, keep machine-specific File Paths blank.
- `startup.blend` — user-controlled; only changes when you save it.

**Do not sync:**

- `extensions/.cache/`, `~/Library/Caches/Blender/`
- `recent-files.txt`, `bookmarks.txt`, `platform_support.txt`
- `extensions/blender_org/` and `extensions/lab_blender_org/` content — let Blender's extension system re-download these

## CLI

Homebrew installs a wrapper at `/opt/homebrew/bin/blender` pointing into the `.app` bundle.

Common headless commands:

```bash
# Render a single frame
blender -b scene.blend -o //out/frame_#### -f 1

# Render an animation
blender -b scene.blend -a

# Run a Python script with no GUI
blender -b -P script.py -- arg1 arg2
```

Use `-b` (background) before file args. `-E CYCLES`, `-F PNG`, `--python-expr "..."` are also useful.

## Addons

Two systems coexist:

- **Extensions (4.2+, preferred)** — Preferences → Get Extensions, browse `extensions.blender.org` or add a custom repo URL. Installs land in `extensions/<repo_id>/<addon>/`.
- **Legacy addons** — drop a `.py` or package directory into `<X.Y>/scripts/addons/`, then enable in Preferences → Add-ons.

Built-in (no install needed): Node Wrangler, LoopTools, Copy Attributes Menu, Import Images as Planes, 3D Print Toolbox, Extra Objects.

Popular third-party: BlenderKit (asset library), MACHIN3tools, Hard Ops / BoxCutter (paid), Auto-Rig Pro (paid).

## MCP Server

Blender 5.1+ ships with an official MCP server from Blender Lab (extension `lab_blender_org/mcp/`). It runs a TCP socket on `localhost:9876`. Two modes:

- **GUI** — enable the "MCP" extension in Preferences → Extensions, start it from the addon panel.
- **Headless** — `blender --background scene.blend --command blender_mcp [--host localhost --port 9876]`

A separate community server exists at [ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp), installed as a legacy addon with `uvx blender-mcp` as the client.

This repo ships an [`apps/blender/.mcp.json`](./.mcp.json) that runs the official server via `uvx` (the published `blender-mcp` package from the Blender Lab repo), pointed at `localhost:9876`. You still need to enable the "MCP" extension inside Blender (Preferences → Extensions) and start it from the addon panel before the server can connect.

## References

- [Blender Download](https://www.blender.org/download/)
- [Directory Layout (Blender Manual)](https://docs.blender.org/manual/en/latest/advanced/blender_directory_layout.html)
- [Command Line Arguments](https://docs.blender.org/manual/en/latest/advanced/command_line/arguments.html)
- [Extensions Platform](https://extensions.blender.org/)
- [MCP Server (Blender Lab)](https://www.blender.org/lab/mcp-server/)
