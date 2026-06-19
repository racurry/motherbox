# apps/ inventory — findings

Deep inventory of all **45 app directories** under `apps/`, assessed against
`docs/GOAL.md` (the layer architecture). Every claim below was verified by
reading the actual scripts/configs and checking live machine state on
2026-06-17. Findings are grouped **by type**; a per-app reference index is in
the Appendix.

Method note: install methods were verified from the scripts themselves (not the
READMEs, which are frequently stale — see §D2). Live state was checked with
`which -a`, `brew leaves`, `brew info`, `git ls-files`, and `git check-ignore`.

______________________________________________________________________

## TL;DR — the big rocks

1. **The L2 runtime layer does not exist.** `mise` is not installed and is in no
   Brewfile or script. Node is owned by Homebrew; Elixir/Erlang/Rust are absent
   entirely. `apps/elixir/elixir.sh` would **fail on a fresh machine**. (§A1, §A2)
2. **Homebrew is being used for package managers** — `pnpm` and `yarn` are brew
   formulae, a direct breach of "Homebrew is NEVER for language runtimes or
   package managers." (§A1)
3. **The compliant L3 Python layer exists but is empty** — `uv` is installed
   correctly (standalone), but `apps/uv/uv-tools` has zero tools, while Python
   tools that belong there (`ruff`, `openai-whisper`) sit in brew instead. (§A3)
4. **~13 app scripts `brew install` imperatively**; 8 of those **duplicate** a
   Brewfile declaration and 4 are **undeclared** (invisible to `brew bundle` and
   the audit). (§B2, §B3)
5. **Seven `.mcp.json` files have no loader at all** — they sit loose in app dirs
   and are copy-pasted by hand. They are the clearest new chezmoi candidate. (§C3)
6. **Five apps claim "Installed via Homebrew" but are in no Brewfile** — silent
   install-coverage gaps. (§B5)

______________________________________________________________________

## A. Layer-architecture violations (the crux)

### A1. Hard violations — runtimes & package managers via Homebrew

GOAL: *"Homebrew is NEVER for language runtimes or package managers."* Live state
confirms `node`, `npm`, `pnpm`, `yarn`, `deno` all resolve to `/opt/homebrew/bin`.
Two distinct cases — only the first is a *deliberate declaration*:

**Declared in a Brewfile (deliberate — these are the real fixes):**

| Item          | Where                   | Why it violates                                                      |
| ------------- | ----------------------- | -------------------------------------------------------------------- |
| `brew "pnpm"` | `apps/brew/Brewfile:20` | pnpm is the L3 **Node package manager** — must not be brew-installed |
| `brew "yarn"` | `apps/brew/Brewfile:30` | Node package manager via brew                                        |

**Runtimes brew owns *transitively* (pulled in as dependencies, not declared):**

| Runtime                      | Pulled in by                                                                 | Layer note                                                                    |
| ---------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `node`                       | `pnpm`/`yarn` formulae                                                       | L2 → should be `mise`; this is *how* brew ends up owning Node                 |
| `deno` (JS/TS runtime)       | `yt-dlp` (`personal.Brewfile:2`; confirmed via `brew uses --installed deno`) | a second JS/TS runtime on PATH via brew, benign plumbing but unmanaged per L2 |
| `python@3.13`, `python@3.14` | brew dependencies                                                            | Python runtime brew-owned; L2 wants `mise`                                    |

The distinction matters for action: removing `pnpm`/`yarn` (and re-homing Node on
`mise`) is the deliberate fix. `node`/`deno`/`python` are dependency plumbing —
you can't simply `brew uninstall` them; they disappear once their declared
parents (and the L2 migration) are resolved. They are listed so the inventory of
"languages installed via brew" (the task's named example) is complete, not
because each is an independent to-do.

### A2. The missing L2 runtime layer

There is **no runtime manager at all**. `mise` (the GOAL default) is not
installed, not in any Brewfile, and has no `apps/mise/` directory.
(Per `project_asdf_removed_2026` memory: asdf was removed June 2026, replacement
"likely mise" still pending.)

Consequences found:

- **`apps/elixir/elixir.sh:23`** does `require_command mix` and then
  `mix archive.install hex phx_new` — it **assumes** an Elixir runtime that has
  no source anywhere in the repo. Live state: `elixir`/`mix`/`erl` are **not
  installed**, so this script fails immediately on a clean machine.
  `apps/elixir/test_elixir.bats:57` even codifies that setup *should* fail when
  `mix` is missing. This is the cleanest illustration of the absent L2 layer.
- **Node** fills its L2 slot the wrong way (brew, §A1) instead of `mise`.
- **Rust** (`rustc`/`cargo`/`rustup`) is absent; GOAL wants `rustup`. No app dir.

### A3. Soft violations — language tools via brew that belong in L3

These are linters/formatters/tools, not runtimes, so not a *hard* breach — but
they are language-ecosystem packages that the layer model wants installed via
the L3 package manager (`uv` for Python, `pnpm`/`npm` for Node), not L1 brew.

- **Python tools → should be `uv tool`** (i.e. belong in `apps/uv/uv-tools`):
  - `brew "ruff"` — `apps/brew/Brewfile:23`
  - `brew "openai-whisper"` — `apps/brew/Brewfile:18` (a pip package shipped as a brew formula)
- **Node/JS tools → should be pnpm/npm-managed:**
  - `brew "eslint"` (`Brewfile:6`), `brew "prettier"` (`:21`), `brew "biome"` (`:3`), `brew "markdownlint-cli2"` (`:16`)

**Key intersection:** `apps/uv/uv-tools` is **completely empty** (only comment
examples, `uv-tools:1-8`). The compliant L3 Python-tools layer is built and
working but installs nothing, while its rightful contents live in brew. Moving
`ruff`/`openai-whisper`/`mdformat` into `uv-tools` is the single cleanest fix.
(`mdformat` already does this correctly — see below.)

### A4. nvm wired in, conflicting with the mise goal

`apps/direnv/use_nvm.sh:9-10` sources `nvm` (`$NVM_DIR/nvm.sh; nvm use`) — a
**Node version manager** committed as a direnv library and symlinked to
`~/.config/direnv/lib/use_nvm.sh` (`direnv.sh:30`). This is a second, conflicting
runtime-management path versus L2-mise. Once Node moves to mise, this helper
should be replaced with a `use_mise`/native-mise-direnv integration.

### A5. Global-npm coding CLIs riding brew-owned Node

- `apps/codex-cli/codex-cli.sh:40` → `npm install -g @openai/codex`
- `apps/gemini-cli/gemini-cli.sh:39` → `npm install -g @google/gemini-cli`

Both use `npm install -g` (not the L3 `pnpm` default) onto the brew-owned global
Node. Defensible (these track daily upstream releases that brew can't keep up
with), but they are global installs on an unmanaged runtime.

Related: **`audit_apps.py:158,224` reads `apps/brew/.default-npm-packages`,
which does not exist.** So global npm packages always report "not tracked," and
**nothing anywhere installs npm globals** — there is no npm-globals mechanism at
all, just a dangling reference in the auditor.

______________________________________________________________________

## B. Homebrew install findings

### B1. Already covered by a Brewfile (the "already installed" bucket)

These app dirs map cleanly to an existing Brewfile declaration (installed by
`brew.sh` via `brew bundle`):

- **core.Brewfile:** `direnv`, `zsh` (+ `pure`, `zsh-autosuggestions`,
  `zsh-syntax-highlighting`), plus infra `chezmoi`/`fzf`/`jq`/`mas`/`1password-cli`.
- **main Brewfile (casks):** `chrome` (`google-chrome`), `codex-app`, `hazel`,
  `keycastr`, `mute_deck` (`mutedeck`), `obsidian`, `ollama` (`ollama-app`),
  `raycast`, `shortcutdetective`, `shottr`, `stream_deck` (`elgato-stream-deck`),
  `vscode` (`visual-studio-code`).
- **main Brewfile (formulae):** `eslint`.
- **personal.Brewfile:** `bambu-studio`, `openscad` (declared as
  `openscad@snapshot` — see §B4), `scansnap` (`fujitsu-scansnap-home`), `steam`.

Note: `cask "claude"` (`Brewfile:38`) is the **Claude desktop app**, *not* the
`claude-code` CLI that `apps/claudecode/` installs (§D2). Don't conflate them.

### B2. Duplications — imperative `brew install` in own script AND declared in a Brewfile

These install the same cask twice over (once via `brew bundle`, once when the
app's own `setup` runs). Harmless but redundant, and the imperative line should
be dropped in favor of the declarative Brewfile entry:

| App               | Imperative install                       | Also declared                           |
| ----------------- | ---------------------------------------- | --------------------------------------- |
| chrome            | `chrome.sh:31`                           | `Brewfile:45`                           |
| codex-app         | `codex-app.sh:32` (`--adopt`)            | `Brewfile:39`                           |
| keycastr          | `keycastr.sh:34` (`ensure_brew_package`) | `Brewfile:50`                           |
| shortcutdetective | `shortcutdetective.sh:58`                | `Brewfile:60`                           |
| bambu-studio      | `bambu-studio.sh:30`                     | `personal.Brewfile:7`                   |
| scansnap          | `scansnap.sh:32`                         | `personal.Brewfile:14`                  |
| steam             | `steam.sh:32`                            | `personal.Brewfile:31`                  |
| ollama            | `ollama.sh:60`                           | `Brewfile:56` (see §B4 — name mismatch) |

Subtlety: `ensure_brew_package` and the guarded scripts only fire when the
command is missing — but for GUI casks like **keycastr** the guard checks
`command -v keycastr`, which never exists (the cask installs `KeyCastr.app`, no
CLI), so the imperative install fires on **every** run regardless.

### B3. Undeclared imperative installs (invisible to `brew bundle` + audit)

These `brew install` from their own scripts but appear in **no** Brewfile, so
`brew bundle` and `audit_apps.py` can never see or reconcile them:

- **comet** — `comet.sh:30` `brew install --cask comet`
- **chatgpt-atlas** — `chatgpt-atlas.sh:30` `brew install --cask chatgpt-atlas`
- **figma** — `figma.sh:31` `ensure_brew_package figma figma cask`
- **blender** — `blender.sh:40` `brew install --cask blender`

Fix: add these casks to the appropriate Brewfile and drop the imperative line.

### B4. Cask-name discrepancies (verified via `brew info`)

- **openscad — genuine split.** `openscad.sh:104` installs the **stable** cask
  `openscad` (v2021.01), but `personal.Brewfile:24` declares
  **`openscad@snapshot`** (v2026.06.12). These are **different casks** that
  install/upgrade independently and can coexist. Setup and inventory disagree on
  which OpenSCAD exists — a latent bug. Pick one.
- **ollama — three names, one app.** Brewfile declares `ollama-app` (`:56`),
  `ollama.sh:60` installs cask `ollama` (an **alias** of `ollama-app`, confirmed
  via `brew info`), and `README.md:9` says `brew install ollama` (formula form).
  Same app, inconsistent naming. Standardize on `ollama-app`.

### B5. Install-coverage gaps — README claims Homebrew, but no Brewfile entry

Verified: zero declarations across all Brewfiles for these. Their READMEs assert
brew installation, but nothing installs them and the audit can't track them:

- **iterm2** — `README.md:3` "Installed via Homebrew"; no cask anywhere. Likely
  **vestigial** (the repo's real terminal is Ghostty: `Brewfile:44` +
  `home/dot_config/ghostty`). Decide: declare `iterm2` or delete the dir.
- **alfred** — `alfred.sh` sets prefs via `defaults`, but `README.md:9`'s
  `brew install --cask alfred` is undeclared.
- **devonthink** — `README.md:8` documents `brew install --cask devonthink`;
  undeclared. (The script only builds/deploys AppleScripts; never installs.)
- **mailmate** — `README.md:4` "Installed via Homebrew"; undeclared.
- **keyboard_maestro** — `README.md:4` "Installed via Homebrew"; undeclared,
  no script (bare stub).
- **ice** — *intentional* deviation: `jordanbaird-ice` cask is deliberately not
  declared because v0.11.12 crashes on macOS Tahoe; `README.md:35-41` curl-installs
  a pinned beta as the sanctioned last resort. Documented, but still untracked
  until upstream stabilizes.

### B6. Untracked brew leaves (installed, declared nowhere)

Not app dirs, but relevant to "what's in a Brewfile?": these formulae are
installed as top-level leaves but absent from every Brewfile —
`chafa`, `httpie`, `mole`, `ocrmypdf`, `organize-tool`, `poppler`,
`postgresql@17`, `potrace`. Either add them to a Brewfile or prune them.
(`postgresql@17` is a database/runtime worth a deliberate decision.)

______________________________________________________________________

## C. chezmoi findings

### C1. Already managed by chezmoi (no action)

`home/` (chezmoi root via `.chezmoiroot`) already owns: `zsh` (`dot_zshrc.tmpl`

- `.chezmoitemplates/firsthand.zsh.tmpl`), `ghostty`, `git`, `karabiner`, `ruff`,
  `shellcheck`, `yamllint`, `editorconfig`, `markdownlint`, **`mdformat`**
  (`dot_mdformat.toml`), `prettier` (ignore + rc), `1password`, `ssh`. OpenSCAD's
  `OPENSCADPATH` env is also already chezmoi-managed (`home/dot_zshrc.tmpl:66`).

### C2. Should move to chezmoi — ad-hoc symlinks via `link_file`

These scripts hand-roll config symlinks into `$HOME`/`~/.config` using the
`link_file` helper — exactly what chezmoi should own instead:

| Source file                                                   | Symlinked to                               | By                                                                         |
| ------------------------------------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------- |
| `apps/_shared/AGENTS.global.md`                               | `~/AGENTS.md`                              | claudecode.sh:53, codex-cli.sh:32, gemini-cli.sh:32 (**3× the same file**) |
| `apps/claudecode/CLAUDE.global.md`                            | `~/.claude/CLAUDE.md`                      | claudecode.sh:47                                                           |
| `apps/claudecode/keybindings.json`                            | `~/.claude/keybindings.json`               | claudecode.sh:139                                                          |
| `apps/claudecode/statuslines/*`                               | `~/.claude/statuslines/`                   | claudecode.sh:99                                                           |
| `apps/claudecode/hooks/*`                                     | `~/.claude/hooks/`                         | claudecode.sh:123                                                          |
| `apps/direnv/use_nvm.sh`                                      | `~/.config/direnv/lib/use_nvm.sh`          | direnv.sh:30                                                               |
| `apps/vscode/settings.json`, `keybindings.json`, `snippets/*` | `~/Library/Application Support/Code/User/` | vscode.sh:35,44,70                                                         |

Notes:

- `AGENTS.global.md` is linked **three separate times** to one target — a single
  chezmoi-managed `~/AGENTS.md` replaces all three.
- **Exception:** `apps/claudecode/settings.json` is **not** a clean candidate —
  `claudecode.sh:167` does a `jq` **deep-merge** of universal settings into
  `~/.claude/settings.json` (preserving machine-local keys). chezmoi owns whole
  files; this deliberate partial-merge does not map cleanly. Leave as-is or model
  with a chezmoi `modify_` script.
- **vscode caveat:** `README.md:29-36` also tells the user to enable VS Code
  **Settings Sync**, which writes the *same* files the symlinks target. Symlink
  vs Settings Sync will fight. Resolve ownership before migrating. Also
  `settings.json` carries machine-specific values (`geminicodeassist.project`,
  hardcoded `/opt/homebrew` paths) that want chezmoi templating.

### C3. The seven `.mcp.json` files — no loader exists

`apps/{airtable,n8n,obsidian,playwright,readwise,blender,figma}/.mcp.json` each
hold an MCP-server config. **Verified (grep of `run/`, `lib/`, `apps/_shared/`
for `mcp`/`.mcp.json`/`mcpServers` returns nothing): there is no loader, symlink,
or copy step anywhere** that installs these into any Claude client config — the
READMEs say "copy this into your config by hand" (e.g. airtable `README.md:37`,
readwise `README.md:24`). None are in chezmoi. (Note: Claude Code's own
`apps/claudecode/settings.json:3` sets `"enableAllProjectMcpServers": true`,
which auto-trusts a project-local `.mcp.json` *when you open that project* — but
that is per-project trust, not a mechanism that installs or aggregates these
seven app-dir configs into a usable global MCP setup.)

This is the strongest *new* chezmoi candidate: chezmoi should own a single
canonical MCP config. They fit templating well because all secrets are already
`${ENV_VAR}` interpolations (`AIRTABLE_API_TOKEN`, `N8N_API_KEY`/`N8N_API_URL`,
`OBSIDIAN_API_KEY`/`HOST`/`PORT`, `READWISE_TOKEN`) sourced from `~/.zshenv` —
so the rendered file stays secret-free.

Two reconciliations needed before merging:

- **Structural inconsistency:** `n8n`/`playwright`/`blender` wrap servers under a
  `"mcpServers"` key; `airtable`/`figma`/`obsidian`/`readwise` are bare server
  maps. They must be unified into one schema.
- **Runtime dependency (ties back to §A2):** 6 of 7 need an unmanaged runtime —
  Node via `npx` (airtable, n8n, playwright, readwise-enhanced) or Python via
  `uvx` (obsidian, blender). Only the HTTP servers (figma-desktop/remote,
  official readwise) need no local runtime. `playwright` pins `@latest`
  (unpinned — counter to the L4 lockfile goal).

### C4. Deliberately NOT chezmoi (and why)

So these aren't mistaken for migration candidates:

- **Binary plists in `~/Library`** — keycastr, shottr, mute_deck, devonthink,
  stream_deck, hazel: prefs are binary cfprefs, not dotfiles.
- **Cloud/account-synced apps** — chrome, comet, chatgpt-atlas, codex-app,
  codex-cli, gemini-cli, figma, bambu-studio, steam, scansnap, alfred,
  keyboard_maestro: settings live in the vendor cloud.
- **macOS `defaults`** — `apps/macos/` writes system prefs imperatively; this is
  a distinct domain from chezmoi's dotfile templating (don't conflate).
- **App-bundle target** — `apps/mailmate/MotherBox.plist` is plaintext but
  `copy_file`'d into `/Applications/MailMate.app/...` (`mailmate.sh:36`), outside
  chezmoi's `$HOME` domain.
- **Machine-state symlink** — `apps/icloud/` makes a `~/iCloud` symlink via raw
  `ln -s` (not a dotfile).

______________________________________________________________________

## D. Other notes (cross-cutting)

### D1. Install-mechanism infrastructure

- **`apps/mas/`** is the Mac App Store install layer (correct L1 fallback after
  brew): `mas.sh` installs from `apps.txt` (13 shared apps) + `{profile}.txt`
  (17 personal). Skips under `--unattended` (needs interactive Apple-ID auth).
- **`apps/brew/`** is the L1 manager itself (Homebrew install + `brew bundle` +
  `audit_apps.py`). Setup order: Homebrew → core → main → `{profile}` Brewfile.
- **`apps/uv/`** installs `uv` standalone and signs `uv`/`uvx` for TCC/FDA
  persistence (`uv.sh:148-157`) — the **model-citizen** L3 install (not brew).
- **`apps/xcodecli/`** ensures Xcode CLT via `xcode-select --install`; a
  foundational prerequisite, not brew-installable.

### D2. README ⇄ script drift (install method)

READMEs are not a reliable source of truth — several describe a brew install the
script no longer performs:

- **claudecode** — README says brew; script uses `curl https://claude.ai/install.sh` (`claudecode.sh:176`).
- **codex-cli** — README says `brew install --cask codex`; script uses `npm install -g` (`codex-cli.sh:40`).
- **gemini-cli** — README says brew; script uses `npm install -g` (`gemini-cli.sh:39`).
- **mdformat** — README (`:19`,`:64`) claims it symlinks `~/.mdformat.toml`; the
  script does **no** symlink (verified). chezmoi silently took over the file.
- **iterm2 / alfred** — claim brew install with no Brewfile entry (§B5).

### D3. Committed build artifacts

- **devonthink** — `build/Menu/*.scpt` and `build/Smart Rules/*.scpt` are
  **git-tracked** (verified via `git ls-files`) despite being regenerated from
  `src/*.applescript` via `make`/`osacompile` (`Makefile:13-39`). Recommend
  gitignoring `build/`. (The `.applescript` sources are correctly plaintext per
  the `feedback_applescript_plaintext` convention.)
- *Corrections to agent reports:* `apps/brew/__pycache__/*.pyc` and
  `apps/devonthink/build/.tmp/pr_cache_main` are **gitignored** (not committed),
  and `apps/claudecode/.DS_Store` is **not** git-tracked — these are on-disk only.

### D4. Idempotency & helper inconsistencies

- Some imperative installers guard with `brew list --cask` (blender, openscad,
  shortcutdetective); others fire unconditionally (bambu-studio, steam, scansnap,
  chrome, comet, chatgpt-atlas).
- Rosetta: `scansnap.sh:31` uses the `common.sh` `require_rosetta` helper, but
  `shortcutdetective.sh:28-43` rolls its own inline `install_rosetta`.

### D5. Documentation / naming bugs found

- **mailmate** — `mailmate.md:8` + `README.md:7,11` reference a `Pumpkin.plist`
  that **does not exist** (actual file: `MotherBox.plist`), so the documented
  `cp Pumpkin.plist ...` would fail; README also mislabels it a "theme" when it's
  actually **keybindings**. Plus a dual-doc oddity (`mailmate.md` *and* `README.md`).
- **macos** — `README.md:9` lists `macos_screenshot_settings.png` in Contents,
  but that file only exists at `apps/shottr/assets/`.
- **claudecode** — `commands/` is referenced by `do_commands` (`claudecode.sh:58`)
  and `README.md:21`, but the dir is empty/absent; `do_install` (curl pipe) runs
  on every full `setup` (`claudecode.sh:216`).
- **airtable** — `extract-data.js:12-13` usage comment references an old
  `scripts/extract-airtable-data.js` path that no longer matches its location.
- Cosmetic: mute_deck + stream_deck READMEs have mojibake callout glyphs; shottr
  README has malformed list numbering.

### D6. Secrets handling (healthy)

All MCP configs and token-using scripts reference secrets via env vars
(`${AIRTABLE_API_TOKEN}`, `${READWISE_TOKEN}`, etc.) expected in `~/.zshenv` —
none are hardcoded. shottr pulls its license from 1Password manually. This is
consistent with the repo convention and needs no change.

### D7. Profile / machine specificity

- Profiles (`personal`/`firsthand`) drive Brewfiles, mas lists, uv-tools, and
  `apps/macos/folders.sh` (firsthand-only folders). `firsthand.Brewfile` holds
  only `gcloud-cli`.
- `apps/vscode/settings.json` hardcodes machine-specific values
  (`geminicodeassist.project: watchful-destination-...`, `/opt/homebrew` paths)
  with no profile templating; `NOTES.md` flags `datadog.datadog-vscode` as
  work-only and undecided.

______________________________________________________________________

## Recommended next moves (derived from the above)

1. **Stand up L2: add `mise`** (declare in core.Brewfile, add `apps/mise/`), then
   move Node off brew and give Elixir/Erlang a real source so `elixir.sh` works.
2. **Remove `pnpm`/`yarn` from the Brewfile** (§A1) once mise/corepack owns Node tooling.
3. **Fill `apps/uv/uv-tools`** with `ruff`, `openai-whisper`, `mdformat`; drop the
   brew formulae (§A3).
4. **Migrate the §C2 symlinks + the §C3 `.mcp.json` files into chezmoi**; collapse
   the 3× `AGENTS.md` link into one; build a single canonical MCP config.
5. **Reconcile brew installs:** drop the 8 duplicate imperative installs (§B2),
   declare the 4 undeclared ones (§B3), fix openscad stable-vs-snapshot and the
   ollama naming (§B4), and declare the 5 README-only apps or delete the stubs (§B5).
6. **Housekeeping:** gitignore `apps/devonthink/build/`; fix the stale READMEs and
   naming bugs (§D2, §D5).

______________________________________________________________________

## Appendix — per-app reference index

Legend — **Install:** `brew✓`=declared in Brewfile (C=core/M=main/P=personal),
`brew!`=imperative in own script, `dup`=both, `npm`/`uv`/`curl`/`mas`/`xcode`,
`cfg`=config-only/no install, `gap`=README claims brew but undeclared.
**chez:** ✓=already / →=should move / –=n/a. **Layer:** ✓=ok / ⚠=violation or concern.

| App               | What                | Install      | In Brewfile?              | chez |  Layer  | Key note                                            |
| ----------------- | ------------------- | ------------ | ------------------------- | :--: | :-----: | --------------------------------------------------- |
| \_shared          | shared AGENTS rules | cfg          | –                         |  →   |    ✓    | `AGENTS.global.md` linked 3× → `~/AGENTS.md`        |
| airtable          | DB MCP + export     | cfg/npx      | no                        |  →   |    ⚠    | `.mcp.json` no loader; npx needs Node               |
| alfred            | launcher prefs      | gap          | no                        |  –   |    ✓    | defaults-write; app undeclared                      |
| bambu-studio      | 3D slicer           | dup          | P:7                       |  –   |    ✓    | imperative + declared                               |
| blender           | 3D suite            | brew!        | **no**                    |  –   |    ⚠    | undeclared; uvx MCP needs Python                    |
| brew              | L1 manager          | curl(self)   | n/a                       |  –   |    ✓    | `.default-npm-packages` missing                     |
| chatgpt-atlas     | AI browser          | brew!        | **no**                    |  –   |    ✓    | undeclared imperative                               |
| chrome            | browser             | dup          | M:45                      |  –   |    ✓    | imperative + declared                               |
| claudecode        | Claude Code CLI     | curl         | no (`claude`=desktop)     |  →   |    ✓    | curl install; CLAUDE.md/keybindings/hooks symlinked |
| codex-app         | Codex desktop       | dup          | M:39                      |  –   |    ✓    | `--adopt` + declared                                |
| codex-cli         | Codex CLI           | npm          | no                        |  –   |    ⚠    | `npm -g` on brew node                               |
| comet             | AI browser          | brew!        | **no**                    |  –   |    ✓    | undeclared imperative                               |
| devonthink        | doc mgr + scripts   | gap          | **no**                    |  –   |    ✓    | committed `build/*.scpt`; app undeclared            |
| direnv            | env switcher        | brew✓        | C:7                       |  →   |    ⚠    | `use_nvm.sh` (nvm vs mise); lib symlinked           |
| elixir            | Phoenix gen         | other        | no                        |  –   |    ⚠    | assumes `mix`; **no runtime exists → fails**        |
| eslint            | JS linter cfg       | brew✓        | M:6                       |  –   | ⚠(soft) | global brew vs per-project; template dir            |
| figma             | design app + MCP    | brew!        | **no**                    |  –   |    ✓    | undeclared; HTTP MCP (no runtime)                   |
| gemini-cli        | Gemini CLI          | npm          | no                        |  –   |    ⚠    | `npm -g` on brew node                               |
| hazel             | file automation     | brew✓        | M:47                      |  –   |    ✓    | README-only                                         |
| ice               | menubar mgr         | curl         | **no (intentional)**      |  –   |    ✓    | Tahoe-crash workaround; pinned beta                 |
| icloud            | iCloud symlink      | cfg          | no                        |  –   |    ✓    | raw `ln -s`, not a dotfile                          |
| iterm2            | terminal            | gap          | **no**                    |  –   |    ✓    | vestigial (Ghostty is primary)                      |
| keyboard_maestro  | macros              | gap          | **no**                    |  –   |    ✓    | bare stub, undeclared                               |
| keycastr          | keystroke viz       | dup          | M:50                      |  –   |    ✓    | guard misfires → installs every run                 |
| macos             | system defaults     | cfg          | n/a                       |  –   |    ✓    | `defaults write`; not chezmoi domain                |
| mailmate          | email client        | gap          | **no**                    |  –   |    ✓    | Pumpkin.plist bug; plist→app bundle                 |
| mas               | MAS installer       | mas          | n/a                       |  –   |    ✓    | infra; apps.txt + personal.txt                      |
| mdformat          | md formatter        | uv           | no (intentional)          |  ✓   |    ✓    | model L3 use; README symlink claim stale            |
| mute_deck         | call mute           | brew✓        | M:53                      |  –   |    ✓    | README-only                                         |
| n8n               | automation MCP      | cfg/npx      | no                        |  →   |    ⚠    | `.mcp.json` no loader; npx needs Node               |
| obsidian          | notes + MCP         | brew✓        | M:55                      |  →   |    ⚠    | app declared; uvx MCP needs Python                  |
| ollama            | local LLM           | dup          | M:56                      |  –   |    ✓    | 3 names (ollama/ollama-app/formula)                 |
| openscad          | code CAD            | brew!        | P:24 (`@snapshot`≠stable) |  –   |    ✓    | **stable vs snapshot split**                        |
| playwright        | browser MCP         | cfg/npx      | no                        |  →   |    ⚠    | `@latest` unpinned; npx needs Node                  |
| raycast           | launcher            | brew✓        | M:57                      |  –   |    ✓    | script-command not wired in                         |
| readwise          | highlights MCP      | cfg/npx+http | no                        |  →   |    ⚠    | `.mcp.json` no loader                               |
| scansnap          | scanner             | dup          | P:14                      |  –   |    ✓    | imperative + declared; Rosetta                      |
| shortcutdetective | hotkey diag         | dup          | M:60                      |  –   |    ✓    | inline Rosetta helper                               |
| shottr            | screenshots         | brew✓        | M:61                      |  –   |    ✓    | license via 1Password                               |
| steam             | games               | dup          | P:31                      |  –   |    ✓    | imperative + declared; Rosetta                      |
| stream_deck       | Stream Deck         | brew✓        | M:42                      |  –   |    ✓    | README-only                                         |
| uv                | Python pkg mgr      | curl         | no (correct)              |  –   |    ✓    | standalone+signed; **uv-tools empty**               |
| vscode            | editor              | brew✓        | M:65                      |  →   |    ✓    | settings/snippets symlinked; Sync conflict          |
| xcodecli          | Xcode CLT           | xcode        | n/a                       |  –   |    ✓    | prerequisite                                        |
| zsh               | shell config        | brew✓        | C:11                      |  ✓   |    ✓    | already in chezmoi                                  |
