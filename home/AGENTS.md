# Rules for Coding Agents

- **Existing conventions win**: When a project already has an established convention that conflicts with these rules, follow the project and note the divergence; never "fix" it unprompted
- **Package management**: For managed runtimes (node/python/ruby/etc) under a devcontainer or version manager, install packages locally to the project; never install globally

## Project environments

- Projects should use a devcontainer for consistency, reproducibility, and isolation. Skip for throwaway or single-file scripts.
- If a project cannot/does not use a devcontainer, pin runtime versions per-project. Use `direnv` for organizing project environments (venvs, PATH, env vars, etc.).

## Project structure

- **Default license**: NEVER include license information in generated code unless explicitly requested by the user
- **Author attribution**: NEVER include author attribution in generated code unless explicitly requested by the user
- **Running scripts**: ALWAYS use local paths for execution (`./script.sh`); NEVER fully qualified paths (`/Users/user/path/to/script.sh`)
- **Writing temporary files**: ALWAYS use a local `./.tmp` directory for temporary files; NEVER use system temp directories like `/tmp` or `/var/tmp`. Ensure `./.tmp` is gitignored.

## Secrets and environment variables

- **Secrets storage**: API tokens, passwords, and sensitive data go in `~/.zshenv` (loaded automatically by zsh, not tracked in git)
- **Shared env vars**: Non-secret environment variables that can be committed go in the repo-managed `.zshrc`
- **Documenting secrets**: Tell users to add exports to `~/.zshenv`, never include actual values

## Verifying claims

- **Verify before asserting existence**: NEVER state that a file, directory, database, process, or resource exists or does not exist unless a tool call just confirmed it. Reasoning about how a system "should" behave is a hypothesis, not a finding — never report it as fact.
- **Check named paths**: If a path or name appears anywhere you've read (script, config, log), check that exact path before concluding anything about it.
- **Negative claims need proof too**: "X doesn't exist" / "the data was lost" demand the same verification as positive claims. Absence is a measurement, not a default.
- **Separate verified from inferred**: State confirmed facts plainly; label guesses as guesses with low-confidence wording.
- **Verify before consequential conclusions**: Before any conclusion that would change what the user does (delete, re-import, rebuild), verify it first — checking is cheap; acting on a wrong assumption isn't.

## Git rules

- **Git commands**: Use `git` directly, not `git -C /path` - the working directory is already the repo root
- **Git commits**: ALWAYS use terse, concise, one line messages describing the change. NEVER add attribution text (no "Generated with Claude Code", no "Co-Authored-By:"). NO emojis.
