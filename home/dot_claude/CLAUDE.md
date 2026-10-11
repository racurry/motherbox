# Rules for agents

## Writing READMEs and documentation

- **Docs are for the present**:
  - Write for the user of today. Do not mention a change or what things used to do. History is in the git log; we are helping the users who come tomorrow.

## Building UIs

- **Users don't care about technical details or historical changes**
  - User-facing copy should help today's user _do things_.
  - Every UI element has to earn its place.  Don't fill space or tell the story of what you did.
  - Do not add UI elements or copy describing an implementation decision.
  - Do not add UI elements or copy that describe what you changed, what things used to do, or what they don't do anymore.
  - Ask: **Would this copy still belong here if the feature had always worked this way?** If not, omit it.

## Keep AI tooling agnostic

**Use standards-based or broadly adopted tools**:

- The main instructions file should always be an `AGENTS.md` in the project root. Add a `.claude/CLAUDE.md` with `@../AGENTS.md` for Claude.
- Agent skills go in `.agents/skills`. Symlink them to `.claude/skills/`.
- Use `.mcp.json` files for project MCP connectors. Add them to `.codex/config.toml` for Codex support.

## Coding projects

- **Use my default stack when adding new codebases:** I use **mise**. For languages, **Python** with **uv**, or **TypeScript** with **pnpm**.
  - For new projects, or for existing projects with no existing dev ecosystem, use my stack.
  - If a project already has a dev ecosystem, use what is in there.
- **Keep project dependencies contained and portable:**
  - Keep configurations, tools, and dependencies project scoped. No global installs. Use idiomatic config files: `config.toml`, `pyproject.toml`, `package.json`, etc.
- **No open source boilerplate**
  - I work in personal or work codebases. Never add open source info, licenses, community, contributing guides, attribution, or other such detritus.
- **Keep the repo worktree friendly**
  - I make heavy use of worktrees. We want to ensure friendly worktree flows, if possible.
  - Use worktree include and ignore files, setup scripts, teardown scripts, and so on as needed.
  - If possible, the application should be able to run multiple parallel instances, with worktree-specific app IDs, ports, and so on.
