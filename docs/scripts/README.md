# Scripts

Scripts in `scripts/` are standalone utilities added to PATH.

## When to Add Here

Add a script to `scripts/` when it:

- Is a general-purpose utility (not app-specific)
- Should be callable from anywhere on the system
- Is self-contained (no sourcing of repo libraries)

## Requirements

- Must support `--help` flag
- Must be executable (`chmod +x`)
- No file extension (called as `scriptname`, not `scriptname.sh`)
