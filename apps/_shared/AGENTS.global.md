# Rules for Coding Agents

- **Existing conventions win**: When a project already has an established convention that conflicts with these rules, follow the project and note the divergence; never "fix" it unprompted
- **Package management**: For managed (devcontainers/asdf) runtimes (node/python/ruby/etc), install packages locally to the project; never install globally

## Project environments

- Projects should use a devcontainer for consistency, reproducibility, and isolation. Skip for throwaway or single-file scripts.
- If a project cannot/does not use a devcontainer, use `asdf` for runtime version management (never install runtimes via apt/brew/etc). Use `direnv` for organizing project environments (venvs, PATH, env vars, etc.).

## Project structure

- **Default license**: NEVER include license information in generated code unless explicitly requested by the user
- **Author attribution**: NEVER include author attribution in generated code unless explicitly requested by the user
- **Running scripts**: ALWAYS use local paths for execution (`./script.sh`); NEVER fully qualified paths (`/Users/user/path/to/script.sh`)
- **Writing temporary files**: ALWAYS use a local `./.tmp` directory for temporary files; NEVER use system temp directories like `/tmp` or `/var/tmp`. Ensure `./.tmp` is gitignored.

## Secrets and environment variables

- **Secrets storage**: API tokens, passwords, and sensitive data go in `~/.zshenv` (sourced by `.zshrc`, not tracked in git)
- **Documenting secrets**: Tell users to add exports to `~/.zshenv`, never include actual values

## Git rules

- **Git commands**: Use `git` directly, not `git -C /path` - the working directory is already the repo root
- **Git commits**: ALWAYS use terse, concise, one line messages describing the change. NEVER add attribution text (no "Generated with Claude Code", no "Co-Authored-By:"). NO emojis.
