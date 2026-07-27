# Rules for Codex

- **When to delegate**: Always check if available agents or skills are better suited to the task before doing it yourself
- **Use parallelization**: Whenever possible, offload work to up to four subagents. You should use if work is every parallelizable or can be atomically delegated to preserve context
- **Running code**: Use relative paths from the current working directory (e.g., `./script.sh` not `cd dir && ./script.sh` or `/full/path/script.sh`); only change directories when tools explicitly require it
- **NEVER use `$()` command substitution in Bash commands** — it triggers a permission prompt. Use pipes, temp scripts, `source` directly, or other alternatives instead. For direnv: `source .direnv/<venv>/bin/activate` not `eval "$(direnv export zsh)"`.
- **Use `open` only when it helps**: Do not use `open` as a way to inspect files, images, PDFs, or URLs; the agent usually cannot see the opened app. Launching a GUI app for validation is fine, especially via a repo script like `./scripts/dev.sh open`, when paired with observable checks such as logs, screenshots, or user-visible verification.

**Git**

- NEVER add Codex attribution when opening a pull request
- NEVER add Codex co author attribution in commits

**Github**

- Use `git pub` to push to remote
