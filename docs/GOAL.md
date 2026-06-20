# motherbox

## What

motherbox is a utility drawer for managing my computers. It includes scripts, notes, configurations and other errata that helps me set up new machines, maintain existing ones, and work the way I like to work.

## Ownership layers

General management principles for how things get installed and managed. Things are split by ownership and responsibility.

- Layer 1 - Host tools & applications: cross-project and insensitive to project versions. Homebrew owns it.
- Layer 2 - Runtime/toolchain: executes or compiles project code. Mise, rustup, or Xcode owns it.
- Layer 3 - Package manager: resolves and installs ecosystem dependencies. The ecosystem's package manager owns it.
- Layer 4 - Project tool: affects project behavior or output. Declare it in the project.
- Cross-cutting - Configs are in chezmoi. Secrets are in 1Password.

**Layer 1 - Host tools & applications:**

Graphical applications, global command-line tools, native libraries, and host-level services. Anything that should be installed at the system level and available globally, regardless of language or project.

Homebrew is the owner. If Homebrew cannot be used, then install from the app store with `mas`. Last resort is manual installation with instructions in a markdown file.

These tools are for _standalone binaries_.  If installing a global tool would pull in a runtime, its not a layer 1 tool.  Use global tools in Mise runtimes.

**Layer 2 - Runtime/toolchain:**

Mise by default:

- Python, Node, Ruby, Go

Exceptions are languages that ship with their own strong version manager:

- Rustup for Rust
- Xcode for Swift

Runtime managers are installed using Layer 1 mechanisms. Homebrew installs mise; the App Store or Xcode installer installs Xcode. Layer 2 starts once the manager owns runtime versions.

Mise is for runtime versions.  Use mise to manage runtime-specific global tools, defined directly in the mise config.toml file.

**Layer 3 - Package managers:**

We want modern, fast, but reliable tools.

- uv for Python packages
- pnpm for Node
- cargo for Rust

Don't use Homebrew for global cli tools that seem language specific. `brew install eslint` pulls in node and npm, an un-managed runtime that drifts from the mise one.

**Layer 4 - Project dependencies:**

Dependencies are declared in the standard files for each language, and lock files are committed to the repository to ensure reproducibility. We want to standardize for my own apps and projects, but also to follow common conventions so that new projects are easy to set up.

Eg:

- pyproject.toml with uv.lock for Python
- package.json with pnpm-lock.yaml for Node
- Cargo.toml with Cargo.lock for Rust

**Tiebreakers:**

- if a runtime or toolchain version needs to be pinned per-project, mise owns it. node@22 in mise, ripgrep in Homebrew
- global CLI ownership is by mechanism, not language: standalone binary with no runtime drag -> Homebrew (ripgrep, ruff); ecosystem package -> mise tool or global install for the language
- Python turf: mise owns the interpreter; uv owns deps/venvs and global tools. Don't let uv install Python. Use `python-preference = "only-system"` in uv.

**Cross-cutting - Configs and secrets:**

chezmoi for dotfiles and config. Any config that can be run through chezmoi should be. Chezmoi manages different machines using custom `profile` and `machine` data values.

Secrets live in 1password. If they need to be on the machine, they get templated into chezmoi templates and injected at apply time.

## Scripts & Utilities

They live in ./scripts. I stick these on on the PATH.

## See Also

[Sovereign Tools](https://www.shiinayane.com/series/sovereign-tools/)

## WIP - what is our repo structure?

```bash
- ping       # universal script for managing motherbox.  # TODO - i need to rename this, 
             #    because of the actual `ping` tool
- home/      # chezmoi managed files 
- apps/      # notes, back up files, helper scripts that are app-specific.  stuff i need to 
             #    keep around, but that isn't really auto-manageable
- docs/      # info & instructions on the repo itself
- scripts.   # utility scripts.  I push these onto $PATH for global use
```

Homeless stuff:

- how do I configure all of my AI tools?  I started `./agent-tools`.  That might work?
  - claude, gemini, codex tools - the setup & sync for these is finicky
- where does my 'machines/mini' stuff live?  I bet chezmoi templates can just handle this
