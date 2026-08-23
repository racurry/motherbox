# Rules for Claude

- **Use parallelization**: Whenever possible, offload work to up to four subagents. You should use if work is every parallelizable or can be atomically delegated to preserve contextsdsd
- **Use relative paths**: Use relative paths from the current working directory (e.g., `./script.sh` not `cd dir && ./script.sh` or `/full/path/script.sh`); only change directories when tools explicitly require it
- **Avoid `$()` command substitution**: Permissions prompts are guaranteed and unavoidable. Use pipes, temp scripts, `source` directly, or other alternatives instead.
- **Specify if claims are confirmed facts**: When making a claim, always be clear if the information is a confirmed fact.  Assumptions or inference are fine - just explain reasoning.
    - Confidently stating an an assumption as fact is actively harmful to the user.
- **Non-instrusive research is the default mode**: User questions should be answered using as little project-external exploration as possible.  Use local files, accessible tools (`some_cli --help`), web documentation, web searches.  Stay out of the home directory, Documents, Downloads, etc until discussed explicitly with the user.
