# Code review findings

Full-repo review, 2026-07-02. Grouped by priority; check off as addressed.

## P0 — broken outright

- [ ] `scripts/bin/tcc-sign.sh:23` — sources deleted `scripts/lib/bash/common.sh`; dies under `set -e`. Also reads `PATH_MOTHERBOX_CONFIG` (line 27) and `log_info`/`fail` etc., all defined by that lib. Inline the helpers. Rename to `tcc-sign` (only bin tool with `.sh` suffix).
- [ ] `scripts/utils/icloud.sh:6` — same deleted-lib source; also calls `check_global_flag` from the removed `run/setup.sh` framework (line 320) and uses gawk-only `match()` (line 142). Orphan — nothing invokes it. Fix or delete.
- [ ] copy-mail-link chain dead on fresh machines: `scripts/apps/raycast/copy-mail-link.sh:12`, `scripts/utils/copy-mail-link.applescript:9`, `docs/apps-notes.md:27` all reference `~/.config/motherbox/scripts/...`, but chezmoi only creates the `bin` symlink. Add a `symlink_scripts.tmpl` or repoint to the repo path.
- [ ] `scripts/bin/vidmerge` — `cat`-concatenation (line 47) only works for MPEG-TS; MP4/MOV output contains only the first input. Use ffmpeg concat demuxer.
- [ ] `scripts/bin/vidmerge:51-54` — `--delete-originals` runs `rm -rf` over `filepaths`; with the directory-arg form its own help advertises, it deletes the entire input directory. Delete the resolved file list instead.
- [ ] `scripts/bin/vidmerge:63-66` — single non-flag arg crashes on `File.directory?(nil)`; temp file left behind if ffmpeg fails.
- [ ] `scripts/bin/unfolderify:24` — `mv ./*/**/*(.D) .` runs under `/bin/sh` where the zsh glob is a syntax error; tool does nothing, exits 0. Rewrite with `Dir.glob` + `FileUtils.mv`.
- [ ] `scripts/bin/avitomp4` + `mkvtomp4` (lines 26, 38) — `File.exists?` removed in Ruby 3.2; crashes under mise ruby. Use `File.exist?`.
- [ ] `scripts/bin/avitomp4:24` + `mkvtomp4:24` — `file.split('.')[0...-1].join` drops the dots (`my.file.avi` → `myfile`); use `file.chomp(File.extname(file))`.
- [ ] `home/dot_config/zsh/zshrc.d/40-history.zsh:4` — `HISTDUP=erase` is not a zsh parameter; dedup silently off. Use `setopt hist_ignore_all_dups`.
- [ ] `home/dot_claude/statuslines/executable_statusline.py:188` — PR cache filename embeds raw branch name; `feature/foo` branches throw (swallowed), so caching never works and `gh pr view` runs every refresh. Sanitize the branch name.
- [ ] `scripts/bin/granola-sync:427-440` — `_build_id_index` tests `and index:` (the shared dict) instead of an inside-frontmatter flag; only the first file is ever indexed, rename-cleanup misses everything else.
- [ ] `scripts/bin/granola-sync:490-495` — `publish --note <id>` globs for the note id, but rendered filenames are `date - Title.md`; single-note publish finds nothing.
- [ ] `scripts/bin/gwt:66-70` — outside a git repo the `$(git rev-parse ...)` assignment kills the script (stderr suppressed) before the friendly error. Handle failure on the assignment.
- [ ] `scripts/bin/gwt:77` — `cut -f4 -d/` truncates default branches containing `/`.
- [ ] `scripts/bin/gwt:23-42` — `copy_gitignored_files` runs `git ls-files` from caller's cwd; wrong from a subdir. `cd "$src_root"` first. Also line 250: unconditional `code "$clone_path"` fails the successful clone if VS Code CLI is absent.
- [ ] `scripts/bin/whats-on-port:23` — `lsof -i` matches established connections, not just listeners; `--kill` can SIGKILL e.g. a browser. Use `lsof -iTCP:<port> -sTCP:LISTEN`.
- [ ] `scripts/bin/nerdglyphs:37` — `grep -qi "$filter"` without `--`; a filter starting with `-` (including `-h`) errors.
- [ ] `scripts/bin/folderify:25-41` — subdirectories get moved into folders named after themselves (errors mid-run); extensionless files produce `dir//file`. Filter to `File.file?`, fall back to full name.
- [ ] `scripts/bin/filename_fixer:52-62` — extensionless files renamed to hidden dotfiles; two inputs normalizing to the same name silently clobber; directories renamed too.
- [ ] `scripts/bin/unquarantine:21-23` — `xattr -d` on bundle root only; use `xattr -dr`.
- [ ] `home/dot_config/zsh/zshrc.d/60-convenience.zsh:37-44` — `tldr()` `man` fallback unreachable: `curl -s` exits 0 on cheat.sh misses. Check output or use `curl -sf`.
- [ ] `home/dot_config/zsh/zshrc.d/60-convenience.zsh:10` — `export agents=~/ai_plaground` — verify the directory is really spelled "plaground".
- [ ] `scripts/bin/claude-to-agents:29-42` — not idempotent: its own converged end state (AGENTS.md + symlink) is rejected with "Can't do it". Treat that state as success.

## P1 — unattended setup gap

- [ ] `mother:9,143` — `UNATTENDED` set by `-u`, read by nothing anywhere. Help (line 31) promises behavior that doesn't exist.
- [ ] `home/.chezmoiscripts/run_onchange_after_10-brew.sh.tmpl:17-19` — comment claims mother sets `HOMEBREW_BUNDLE_*_SKIP` for unattended runs; nothing sets it, and the Brewfile has 19 `mas` entries. Wire `-u` → export skip vars, or delete the flag and the comment together.
- [ ] `mother:89` — stale comment "re-apply to skip the interactive bits" (odd indent, no code).
- [ ] `mother:136-151` — extra positional args silently ignored; `-h` works but isn't in help text; `--help` rejected.
- [ ] `mother:62-73` — Homebrew detection hardcodes `/opt/homebrew`; Intel Macs would die under `set -e`. Fine if fleet is all Apple Silicon — decide and document.

## P1 — chezmoi correctness & idioms

- [ ] `home/dot_claude/modify_private_settings.json.tmpl:13-19` — `deep_merge` replaces arrays wholesale, so `permissions.allow`/`ask` clobber live user-scope entries every apply (hooks get additive merging; permissions don't). Union-merge the lists, or document that motherbox owns permissions exclusively.
- [ ] `run_onchange_after_10-brew.sh.tmpl:3` + `run_onchange_after_50-launchagents.sh.tmpl:10` — hash comments use `include` (raw template source); data-only changes (e.g. profile switch) don't re-fire. Use `includeTemplate "..." . | sha256sum`.
- [ ] `home/.chezmoi.toml.tmpl:7` — `diff.command` is a bare name; unresolvable before first apply or outside login shells. Use an absolute path. Also reconsider: repo-wide diff override exists to serve one JSON file whose modify-script already handles semantic equality — still worth it?
- [ ] `home/dot_config/motherbox/symlink_bin.tmpl:1` — hardcodes `~/code/me/motherbox`; the LaunchAgent plist derives repo root via `{{ .chezmoi.sourceDir | dir }}`. Use that here too. Same constant hardcoded a third time in `30-env.zsh:16` (`MOTHERBOX_ROOT`).
- [ ] `home/dot_zshrc` — empty/whitespace-only; renders as either a removal of `~/.zshrc` or a junk one-byte file. Make intent explicit: `.chezmoiremove`, `empty_` prefix, or delete.
- [ ] `home/.chezmoiscripts/run_once_after_40-claude-code.sh.tmpl` — `.tmpl` suffix, zero template directives. Drop the suffix.
- [ ] `home/dot_config/zsh/zshrc.d/99-profile.zsh.tmpl` — renders a no-op file on personal machines; idiom is a `.chezmoiignore` conditional instead of shipping empty files.
- [ ] Template access style inconsistent: `30-folders` uses bare `.profile`; five templates use `index . "profile" | default "personal"`. `promptStringOnce` guarantees the key — pick one style (the guards mask typos under strict mode).
- [ ] `home/dot_config/karabiner/karabiner.json` — fully chezmoi-owned but Karabiner rewrites it at runtime (per-device entries); applies will fight the app. Consider `modify_` merge or document the accepted churn.
- [ ] `home/dot_claude/hooks/executable_enforce-local-tmp.sh:7` + `hooks.json` matcher `""` — guard runs for every tool and greps the entire input JSON, so an Edit/Write whose *content* merely mentions a system temp path is blocked (writing this very findings doc tripped it), while actual usage in forms like `cd /tmp;` or `TMPDIR=/tmp/x` slips past the pattern. Scope the matcher to Bash and match `tool_input.command` only.

## P2 — stale docs & leftovers

- [ ] `README.md:32` — says run `./mother`; that exits 1. Should be `./mother setup` (or make setup the default command).
- [ ] `scripts/README.md:3-4,51-57` — describes deleted `run/sync.sh`/`run/setup.sh` and the old `~/.config/motherbox/scripts` symlink; reality is `symlink_bin.tmpl` + `80-path.zsh`. Rewrite.
- [ ] `scripts/README.md:13` — lists nonexistent `asdf-uninstall`; omits `claude-to-agents` and `tcc-sign.sh`.
- [ ] `docs/apps-notes.md:75,80,81` — image links use `assets/`; directory is `_assets/`. All three screenshots broken.
- [ ] `docs/apps-notes.md:39` — `cp mailmate/Motherbox.plist` → actual path `phantom-zone/mailmate/MotherBox.plist` (dir + case).
- [ ] `docs/apps-notes.md:47` + `scripts/utils/maintenance.sh:19-20` — `npm install -g obsidian-headless` violates ownership table; node globals go via pnpm/mise (like codex/gemini).
- [ ] `docs/apps-notes.md:65` — "Rayccast" typo.
- [ ] `docs/project-tools.md:1` — garbled heading "# Project helper things ESLint".
- [ ] `docs/project-tools.md:13` — references `eslint.config.js` without noting it lives in `phantom-zone/`.
- [ ] `home/dot_config/homebrew/Brewfile.tmpl:9` — comment references nonexistent `setup-stuff/uv`; python tools actually live in mise pipx backend.
- [ ] `home/dot_config/uv/uv.toml:5` — comment references nonexistent `GOAL.md`.
- [ ] `scripts/utils/macos_prefs.sh:6` — usage says `macos_prefs_sudo.sh`; file is `macos_prefs.sh`.
- [ ] `.gitignore:2,3,5,6,9` — `.todone`, `.meta`, `.claude/*.local.md`, `.out`, `.local.zshrc` match nothing anymore.
- [ ] `home/.chezmoitemplates/claude/settings-base.json:117-122` — allowlisted skills look stale (`dmv:commit-push`, `dmv:git-workflow`, `box-factory:agent-design`, `box-factory:status-line`, `/mr-sparkle:lint-md`); verify against installed plugins before pruning. Line 97 `Bash(ruff check:*)` subsumed by `Bash(ruff:*)`.
- [ ] `scripts/apps/airtable/airtable-extract-data.js` — orphan; usage strings reference pre-move path (lines 23-25, 280-284); writes exports into the repo tree (line 311). Fix or move to phantom-zone.
- [ ] `phantom-zone/eslint.config.js:9-15` — template's install instructions say `npm install --save-dev`; rule says pnpm.
- [ ] `README.md:3` — alt text still says "ping" (pre-overhaul script name).
- [ ] `.claude/settings.local.json` — allowlist dominated by pre-overhaul paths (`./run/*.sh`, `./ping`, `./mini/*`, `./machines/*`...). Local-only noise; prune when convenient.

## P2 — redundancy / simplification

- [ ] `scripts/bin/avitomp4` + `mkvtomp4` — byte-identical except extension string. Consolidate into one converter.
- [ ] `scripts/bin/ocrify` vs `ocr-pdf` — overlapping purpose (searchable PDFs via tesseract vs ocrmypdf); `ocrmypdf --image-dpi` could fold image support into one tool. `ocrify` also leaves `.tif` intermediates, ignores `system()` failures, uses deprecated `+matte`.
- [ ] `scripts/bin/ocr-pdf:62-75` — Python inline as a bash string with shell vars interpolated into the source; violates AGENTS.md rule. `splitpdf` shows the correct uv/PEP-723 pattern with the same dependency.
- [ ] `scripts/bin/folderpaint` — committed arm64 binary; build command exists only as a comment in `scripts/_lib/swift/folderpaint.swift`. Add a build step or compile-on-demand wrapper; stop committing the binary.
- [ ] `scripts/bin/swap_extension:40-41` — builds a `/bin/sh` for-loop string with unescaped extensions; already has the list in Ruby — use `FileUtils.mv`. Unused `IGNORED_FILES` + `require 'shellwords'` too.
- [ ] `scripts/bin/batch_rename` — unused `TEMPFILE` (line 7); unsorted `Dir.entries` makes "sequential" arbitrary; collisions clobber; `system("mv")` instead of `FileUtils.mv`.
- [ ] `scripts/bin/iconify` — no `set -euo pipefail`, no ImageMagick check, hardcodes/leaves `icon.iconset` in cwd, deprecated `convert` entry point.
- [ ] `scripts/bin/gh-pr:163,248` — double `2>&1` redirect; `summarize_checks` (146-148) can count a check as both passing and pending.
- [x] Brewfile: both `gh` and `hub` installed; everything uses `gh`. Drop `hub` unless something needs it.
- [x] Brewfile installs `zsh-autosuggestions` but no zshrc.d fragment sources it. Wire it up or drop it.
- [ ] `80-path.zsh:5,10` — PATH entries for `bison` and `~/.opencode/bin`; neither installed by anything in the repo. Declare or delete.
- [ ] `00-package-managers.zsh:6` — `BREW_PREFIX` duplicates `HOMEBREW_PREFIX` from `brew shellenv`.
- [ ] `40-history.zsh:5-7` — `appendhistory` + `incappendhistory` redundant alongside `sharehistory`; keep `sharehistory`.
- [ ] `50-apps.zsh:1-4` — legacy backticks; exports `NPM_TOKEN` into every interactive shell. Prefer lazy per-use resolution.

## P3 — help-rule violations (AGENTS.md: every script needs help)

- [ ] `scripts/bin/256colors`, `nerdglyphs` (`-h` errors), `splitpdf`, `ocr-pdf`, `unquarantine`, `whats-on-port`, `claude-to-agents`, `scripts/utils/maintenance.sh`, `scripts/apps/airtable/airtable-extract-data.js`. Raycast wrappers arguably exempt.

## Verified clean (no action)

- Chezmoi script ordering (10→60); all template data keys defined; `{{ template ... . }}` passes dot correctly.
- LaunchAgent label/filename/hook/plist coherence; `net.aaroncurry` prefix consistent.
- `mother` sudo-keepalive + trap logic; SUDO_ASKPASS helper path matches chezmoi target.
- `macos_prefs.sh` vs `60-macos-defaults.sh` — disjoint (root vs user), deliberate layering not duplication.
- phantom-zone cold-storage invariant holds (no live code depends on it).
- README structure diagram matches layout; AGENTS.md tool table matches reality.
- git config email `aaroncurry@gmail.com` matches actual commit history — not a bug.
- `docs/TODO.md` BOSL2 item still genuinely open.
