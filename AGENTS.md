# mother box - agent overview

**mother box** is a collection of scripts and tools that keep consistent, standardized tooling across multiple macOS systems.  It is a collection of tools that cover many needs; it isn't just a dotfiles, scripts, or set up repo.  It is an overall computer-experience-management tool

## One User

`mother box` built for exactly one person, on current macOS, with current tool versions. All work should optimize for that expectation.  There are no multi-user options, no cross-platform branches, no OS version shims, no backwards compatibility, no review process. Changes are immediately applied across computers - there is never an older version to support.

## Project Structure

```text
.
├── mother          # single base script for managing motherbox
├── docs/           # info, instructions, references - reference as the source of truth, keep up to date
├── home/           # chezmoi managed files - all app configs live here
└── scripts/        # home for all scripts - any script you write lives here
    ├── _lib/       # library code shared by other scripts, separated by language
    ├── apps/       # app-specific scripts - write any app-management scripts here
    ├── bin/        # global utility scripts symlinked onto PATH - reserve for standalone, broadly useful scripts
    └── utils/      # broadly applical scripts, not global utilities - ask for clarification if needed
└── phantom-zone/   # deprecated cold storage; ignore it entirely
```

`./scripts` - **What to do when writing scripts**

- This is a polyglot repo - choose script language by capability and task needs. Bash works for simple tasks, reach for Python or TypeScript as complexity ramps or the library tools are more appropriate.
- There is no house style, shared framework, or established pattern to conform to.  No need to survey `scripts/` for similar scripts or patterns to follow.
- Write scripts in their primary language directly.  Bash scripts that are just thin wrappers around a multiline python string are hard to reason about and maintain.
- All scripts should have a `-h`/`--help` describing purpose and usage. Run it once after writing it to prove the script works.

`./home` - **How to manage Chezmoi**

- Files under `home/` are our definitive source state. 
- Only apply changes with `chezmoi apply`; Never edit the target in `~` directly or copy a file into place.
- Only apply changes with User approval

## Using worktrees

Chezmoi's installed global configuration defines where its source files live: the primary checkout location for the repo. That means:

- You cannot use chezmoi tooling to verify the outcome; it doesn't look at a worktree's changeset.
- You must not try to apply changes directly; do a reasonable self-review of changes and tell the user to apply once the tree is merged.

## Cursor Cloud specific instructions

Cloud agents run Ubuntu on x86_64. `./mother setup` is the Mac setup (Touch ID sudo, Homebrew at `/opt/homebrew`, `chezmoi apply`, LaunchAgents, `defaults`). Run that on a Mac.

The cloud image has `shellcheck`, `jq`, `lsof`, Ruby, current `chezmoi`, and `uv` on `PATH`. There is no dev server to start.

Checks that run here:

- `./mother help`
- `scripts/utils/folders.sh` creates the standard directories under `$HOME`. `MOTHERBOX_PROFILE=firsthand` also creates `~/fh`. It does not need chezmoi.
- `bash -n` on shell scripts. Skip `*.tmpl` files; they contain chezmoi actions.
- `shellcheck -S warning` is clean on the raw bash scripts. Plain `shellcheck` still reports existing info and style findings.
- `uv run scripts/bin/whats-on-port <port>` and `ruby scripts/bin/swap_extension`.
- Render a chezmoi template without applying it:

```bash
chezmoi execute-template \
  --source="$PWD/home" \
  --working-tree="$PWD" \
  --override-data '{"profile":"personal","machine":"cloud"}' \
  --file home/.chezmoiscripts/run_onchange_after_50-launchagents.sh.tmpl
```

Use `machine=mini` to include the mini-only branches. `--promptString` does not fill `promptStringOnce` in this chezmoi version; `--override-data` does. Do not `chezmoi apply` from a cloud agent. The apply hooks call macOS scripts. `chezmoi doctor` reports a missing source dir until chezmoi is initialized, which this environment does not do.
