#!/bin/bash
# PreToolUse hook: block dangerous subcommands that should never run unattended.
# This is a global safety net — even if a project allows a broad command like
# "curl:*" or "find:*", this hook catches the dangerous subset.
#
# Add new patterns here as they come up. Each check should:
#   1. Match the base command
#   2. Match the dangerous flag/subcommand
#   3. Print a clear message explaining what to do instead
#   4. Exit 2 (hard block, no approval prompt)
set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

# ---------------------------------------------------------------------------
# sudo — never run as root
# ---------------------------------------------------------------------------
if echo "$cmd" | grep -qE '(^|\|)\s*sudo\b'; then
    echo "sudo is not allowed. Ask the user to run privileged commands manually." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# find -delete / -exec — use find for searching, rm for targeted removal
# ---------------------------------------------------------------------------
if echo "$cmd" | grep -qE '\bfind\b' && echo "$cmd" | grep -qE '\s-(delete|exec|execdir|ok|okdir)\b'; then
    echo "find with -delete, -exec, or -execdir is not allowed. Use find for searching and rm for targeted removal." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# xargs — allowlist only safe commands (xargs amplifies everything)
# ---------------------------------------------------------------------------
if echo "$cmd" | grep -qE '\bxargs\b'; then
    if ! echo "$cmd" | grep -qE '\bxargs\s+(-[a-zA-Z0-9]+\s+)*(echo|grep|cat|head|tail|wc|file|stat|ls|basename|dirname|realpath|readlink|md5|shasum|sha256sum)\b'; then
        echo "xargs is only allowed with safe read-only commands (echo, grep, cat, head, tail, wc, file, stat, ls, basename, dirname, realpath). Use explicit, targeted commands instead." >&2
        exit 2
    fi
fi

# ---------------------------------------------------------------------------
# git checkout — block discarding working tree changes
# ---------------------------------------------------------------------------
if echo "$cmd" | grep -qE '\bgit\s+checkout\b' && echo "$cmd" | grep -qE '(--\s+\.|--\s+\*|checkout\s+\.)'; then
    echo "git checkout that discards working tree changes is not allowed. Use git stash or ask the user." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# gh api — block write methods
# ---------------------------------------------------------------------------
if echo "$cmd" | grep -qE '\bgh\s+api\b' && echo "$cmd" | grep -qE '\s-X\s*(DELETE|PATCH|POST|PUT)\b'; then
    echo "gh api with write methods (POST/PATCH/PUT/DELETE) is not allowed. Use gh api for reading only, or use specific gh subcommands." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# rm — block recursive on broad/dangerous paths
# ---------------------------------------------------------------------------
if echo "$cmd" | grep -qE '\brm\s+-[a-zA-Z]*r' && echo "$cmd" | grep -qE "(\s/\s|\s/\$|\s~/|\s\\$HOME|\s\.\s|\s\.\$)"; then
    # shellcheck disable=SC2016
    echo 'rm -r on broad paths (/, ~, ., $HOME) is not allowed. Be specific about what you are deleting.' >&2
    exit 2
fi

exit 0
