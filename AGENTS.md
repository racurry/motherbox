# AGENTS.md

## Project Overview

**Mother Box** is a collection of scripts and tools to enable the user to use consistent and standardized tooling across multiple macOS systems.  It is built around an idempotent setup using scripting and chezmoi.  It is also a bunch of helper files and documentation snippets.

## TOP RULES

When renaming or moving files:

- Search the codebase for references to those files and update them accordingly

Scripting:

- This is a polygot repo.  Choose the most appropriate language for the task at hand. That means it is okay to ignore existing patterns and introduce new languages
- Bash is very portable, but complexity and esoteric commands quickly become hard to manage.  Complex scripts generally should reach for a different language
- Write the logic directly in the target language instead of generating code.  Eg, write Python directly instead of wrapping it as a string in a bash script
- All scripts must include a help command or optionthat describes purpose and usage
- Non-bash scripts should be executable with appropriate shebang (#!/usr/bin/env python3, etc.)
- ALWAYS run new scripts after creating them to verify they work!

## Core Structure

```bash
- mother          # universal script for managing motherbox.
- docs/           # info, instructions, references 
- home/           # chezmoi managed files
- phantom-zone/   # cold storage for configs.  project-specific stuff or 
                  # apps i am not using now, but might bring back.
- scripts/ 
  - _lib/         # library code used by other scripts, separated by language
  - apps/         # app-specific scripts
  - bin/          # utilities added to $PATH for global use
  - utils/        # utility scripts that I don't want or need globally
```
