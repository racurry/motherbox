# Rules for Claude

- **When to delegate**: Always check if available agents or skills are better suited to the task before doing it yourself
- **Use parallelization**: Whenever possible, offload work to up to four subagents. You should use if work is every parallelizable or can be atomically delegated to preserve context
- **Running code**: Use relative paths from the current working directory (e.g., `./script.sh` not `cd dir && ./script.sh` or `/full/path/script.sh`); only change directories when tools explicitly require it
- **Never use `open`**: Do not use `open` to view files (PDFs, images, URLs, etc.) — you can't see them. Ask the user to look instead.

**Git attribution**

- NEVER add claude attribution when opening a pull request
- NEVER add claude co author attribution in commits

Apply all rules from @~/AGENTS.md.

- Use `git pub` to push to remote
