# AGENTS.md

## Project Overview

**Mother Box** is a collection of scripts and tools to enable the user to use consistent and standardized tooling across multiple macOS systems.  It is built around an idempotent setup using scripting and chezmoi.  It is also a bunch of helper files and documentation snippets.

Read the @README.md at the project root for goals and structure of the repo.

## Tool ownership & responsibility

See more details at @docs/tool-responsibility.md if needed.

| Thing                                                                       | Tool                         |
| --------------------------------------------------------------------------- | ---------------------------- |
| configurations & configuration orchestration scripts                        | chezmoi                      |
| python packages                                                             | uv                           |
| node packages                                                               | pnpm                         |
| runtime versions - node, python, ruby, go                                   | mise                         |
| rust                                                                        | rustup                       |
| claude, brew                                                                | native installer             |
| coding agent clis - codex, gemini                                           | mise-configured global tools |
| global clis that if installed with brew would drag in language dependencies | mise-configured global tools |
| apps that are on the app store but not in homebrew                          | mas cli                      |
| everything else                                                             | homebrew                     |

## Rules

When renaming or moving files:

- Search the codebase for references to those files and update them accordingly

Scripting:

- This is a polygot repo.  Choose the most appropriate language for the task at hand. That means it is okay to ignore existing patterns and introduce new languages
- Bash is very portable, but complexity and esoteric commands quickly become hard to manage.  Complex scripts generally should reach for a different language
- Write the logic directly in the target language instead of generating code.  Eg, write Python directly instead of wrapping it as a string in a bash script
- All scripts must include a help command or optionthat describes purpose and usage
- Non-bash scripts should be executable with appropriate shebang (#!/usr/bin/env python3, etc.)
- ALWAYS run new scripts after creating them to verify they work!
