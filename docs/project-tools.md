# Project helper things ESLint

## General rules

- devcontainers are the default for any project.  If they can be used reasonably, use them.  Run them on Orbstack for personal projects, colima for work.
- Dependencies are declared in the standard files for each language, and lock files are committed to the repository to ensure reproducibility.  Eg:
  - pyproject.toml with uv.lock for Python
  - package.json with pnpm-lock.yaml for Node
  - Cargo.toml with Cargo.lock for Rust

## Specific tools

- `eslint`: It doesn't support a global configuration. ESLint is configured per-project by design.  To start a new project with ESLint, copy my opinionated default config, `eslint.config.js`, into the project root.
