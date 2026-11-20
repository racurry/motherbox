# Rules for agents

## Writing READMEs and documentation

- **Docs describe the system as it is, not the work you just did**
  - Write for a reader who arrives tomorrow with no knowledge of this session. Tell them what the system does, how to use it, and how to change it.
  - The change you just made is vivid to you and irrelevant to them. Leave out previous states, what changed, and how you got here. Git history holds that.
  - When a change affects the docs, rewrite the affected section in place. Don't append a note about the change.
  - "Now," "no longer," "new," "previously," and "instead of" are signs you are writing a changelog. Restate the sentence as a plain fact: "Config lives in `config.toml`," not "Config moved from `.env` to `config.toml`."
  - Explaining *why* something is the way it is belongs in docs. State it as a current constraint, not as a story.
  - Ask: **Would this sentence still belong if the system had always worked this way?** If not, cut it.

## Building UIs

- **Users don't care about technical details or historical changes**
  - User-facing copy should help today's user *do things*.
  - Every UI element has to earn its place.  Don't fill space or tell the story of what you did.
  - Do not add UI elements or copy describing an implementation decision.
  - Do not add UI elements or copy that describe what you changed, what things used to do, or what they don't do anymore.
  - Ask: **Would this copy still belong here if the feature had always worked this way?** If not, omit it.

## Keep AI tooling agnostic

**Use standards-based or broadly adopted tools**: I routinely use Claude and Codex, and occasionally many others.

- The main instructions file should always be an `AGENTS.md` in the project root. Add a `.claude/CLAUDE.md` with `@../AGENTS.md` for Claude.
- Agent skills go in `.agents/skills`. Use symlinks or dedicated tools to add them to `.claude/skills`, `.cursor/skills`, etc.
- Use `.mcp.json` files for project MCP connectors. Add them to `.codex/config.toml` for Codex support.

## Coding projects

- **Use my default stack when adding new codebases:** I use **mise**. Default to **TypeScript** with **pnpm**. If another language clearly fits the goal better, suggest it instead of forcing TypeScript: for example, Python (with **uv**) for data-heavy work, Go for CLI binaries, Rust for cross-platform native apps.
  - For new projects, or for existing projects with no existing dev ecosystem, use my stack.
  - If a project already has a dev ecosystem, use what is in there.
- **On my Macs, keep project dependencies contained and portable:**
  - I run dozens of projects on each Mac, and they must not contaminate each other. Keep configurations, tools, and dependencies project scoped. No global installs. Use idiomatic config files: `config.toml`, `pyproject.toml`, `package.json`, etc.
- **Global tooling is idiomatic for disposable environments:**
  - Cloud agent VMs (Claude Code cloud, Codex cloud, Cursor cloud), CI runners, containers, and devcontainers exist for one project and get thrown away. Install tools globally, use system package managers, write to `$HOME`, and set global config freely there. Do whatever is simplest and most reliable.
  - Don't bend the project's own files to keep these machines pristine. Environment setup belongs in the environment's setup script or image, not in workarounds inside the repo.
- **No open source boilerplate**
  - I work in personal or work codebases. Never add open source info, licenses, community, contributing guides, attribution, or other such detritus.
- **Keep the repo worktree friendly:**
  - I make heavy use of worktrees, so enable friendly worktree flows whenever possible.
  - Use worktree include and ignore files, setup scripts, teardown scripts, and so on as needed.
  - The application should be able to run multiple parallel instances, with worktree-specific app IDs, ports, and so on.
  - Do not add worktree support if it would make the repo more complex or fragile.
