# mother box - agent overview

**mother box** is a collection of scripts and tools that keep consistent, standardized tooling across multiple macOS systems.  It is a collection of tools that cover many needs; it isn't just a dotfiles, scripts, or set up repo.  It is an overall computer-experience-management tool

## One User

`mother box` built for exactly one person, on current macOS, with current tool versions. All work should optimize for that expectation.  There are no multi-user options, no cross-platform branches, no OS version shims, no backwards compatibility, no review process. Changes are immediately applied across computers - there is never an older version to support.

## Project Structure

```text
.
├── mother          # single base script for managing motherbox
├── docs/           # info, instructions, references - reference as the source of truth, keep up to date
├── home/           # chezmoi managed files - all app configs live here
└── scripts/        # home for all scripts - any script you write lives here
    ├── _lib/       # library code shared by other scripts, separated by language
    ├── apps/       # app-specific scripts - write any app-management scripts here
    ├── bin/        # global utility scripts symlinked onto PATH - reserve for standalone, broadly useful scripts
    └── utils/      # broadly applical scripts, not global utilities - ask for clarification if needed
└── phantom-zone/   # deprecated cold storage; ignore it entirely
```

`./scripts` - **What to do when writing scripts**

- This is a polyglot repo - choose script language by capability and task needs. Bash works for simple tasks, reach for Python or TypeScript as complexity ramps or the library tools are more appropriate.
- There is no house style, shared framework, or established pattern to conform to.  No need to survey `scripts/` for similar scripts or patterns to follow.
- Write scripts in their primary language directly.  Bash scripts that are just thin wrappers around a multiline python string are hard to reason about and maintain.
- All scripts should have a `-h`/`--help` describing purpose and usage. Run it once after writing it to prove the script works.

`./home` - **How to manage Chezmoi**

- Files under `home/` are our definitive source state. 
- Only apply changes with `chezmoi apply`; Never edit the target in `~` directly or copy a file into place.
- Only apply changes with User approval
