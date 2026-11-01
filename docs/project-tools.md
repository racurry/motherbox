# Project tooling

## General rules

- Devcontainers are the default for any project.  If they can be used reasonably, use them.  Run them on Orbstack for personal projects, Colima for work.
- Dependencies are declared in the standard files for each language, and lock files are committed to the repository to ensure reproducibility.  Eg:
  - pyproject.toml with uv.lock for Python
  - package.json with pnpm-lock.yaml for Node
  - Cargo.toml with Cargo.lock for Rust

## Specific tools

- `eslint`: It doesn't support a global configuration. ESLint is configured per-project by design.  To start a new project with ESLint, copy my opinionated default config, `eslint.config.js`, into the project root.

## Formatters

Formatter configs live in `~/.config/motherbox/formatters/` (source: `home/dot_config/motherbox/formatters/`). They sit outside any project's folder tree, so tools only use them when pointed at them explicitly. A config inside a project always wins.

- `markdownlint-cli2.jsonc`: Markdown rules. Pass it with `markdownlint-cli2 --config ~/.config/motherbox/formatters/markdownlint-cli2.jsonc --fix <files>`.

### VS Code format on save

VS Code settings travel through Settings Sync, not chezmoi. Markdown formats on save with the `DavidAnson.vscode-markdownlint` extension and these user settings:

```jsonc
"markdownlint.configFile": "${userHome}/.config/motherbox/formatters/markdownlint-cli2.jsonc",
"[markdown]": {
  "editor.codeActionsOnSave": { "source.fixAll.markdownlint": "explicit" }
}
```

## Git hooks

`git addhook` turns motherbox hooks on per repo. The setting goes in the repo's `.git/config`, so nothing is committed and every worktree shares it. Hooks run alongside any hooks the repo already has.

```bash
git addhook                     # list hooks and which are on in this repo
git addhook format-md           # turn one on
git addhook --remove format-md  # turn it off
git hook list pre-commit        # everything that runs on pre-commit
```

Hooks live in `~/.config/motherbox/git-hooks/<event>/<name>` (source: `home/dot_config/motherbox/git-hooks/`; prefix the file with `executable_`). Adding a file there makes it available to `git addhook`.

- `pre-commit/format-md`: formats staged Markdown with `markdownlint-cli2` and restages it. If a formatted file also has unstaged changes, the hook leaves the formatting in the working tree and stops the commit so you can review and stage it.
