#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Claude Code statusline.

Reads the status hook JSON from stdin and prints one line: the Claude session,
the git branch with the session's line changes, and the git user name.

Schema docs: https://docs.anthropic.com/en/docs/claude-code/status-bar
"""

import json
import os
import subprocess
import sys

RESET = "\033[0m"

# 256-color theme: light gray text, color only for alerts.
MUTE_COLOR = 250
ATTENTION_COLOR = 255  # context 70-85%
ALERT_COLOR = 167  # context 85%+
CLAUDE_ICON_COLOR = 173
GIT_ICON_COLOR = 34
USER_ICON_COLOR = 33

CLAUDE_ICON = "❋"
GIT_ICON = "\uf09b"
USER_ICON = "\uf007"


def fg(text: str, color: int) -> str:
    return f"\033[38;5;{color}m{text}{RESET}"


def muted(text: str) -> str:
    return fg(text, MUTE_COLOR)


def git(cwd: str, *args: str) -> str | None:
    """Run a git command in cwd. Returns stripped stdout, or None on failure."""
    try:
        result = subprocess.run(
            ["git", "-C", cwd, *args],
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None
    return result.stdout.strip() if result.returncode == 0 else None


def git_branch(cwd: str) -> str | None:
    """Current branch name, "detached" off a branch, None outside a repo."""
    if git(cwd, "rev-parse", "--git-dir") is None:
        return None
    return git(cwd, "symbolic-ref", "--short", "-q", "HEAD") or "detached"


def format_tokens(tokens: int) -> str:
    if tokens >= 1_000_000:
        return f"{tokens / 1_000_000:.1f}M"
    if tokens >= 1000:
        return f"{tokens // 1000}k"
    return str(tokens)


def format_duration(ms: int) -> str:
    minutes, seconds = divmod(ms // 1000, 60)
    if minutes == 0:
        return f"{seconds}s"
    hours, minutes = divmod(minutes, 60)
    if hours == 0:
        return f"{minutes}m"
    return f"{hours}h{minutes:02d}m"


def claude_info(data: dict) -> str:
    parts = [muted(data.get("model", {}).get("display_name", "unknown"))]

    agent_name = (data.get("agent") or {}).get("name")
    if agent_name:
        parts.append(muted(agent_name))

    ctx = data.get("context_window") or {}
    usage = ctx.get("current_usage") or {}
    tokens = sum(
        usage.get(key) or 0
        for key in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")
    )
    if tokens > 0:
        pct = ctx.get("used_percentage") or 0.0
        color = ALERT_COLOR if pct >= 85 else ATTENTION_COLOR if pct >= 70 else MUTE_COLOR
        parts.append(f"{fg(format_tokens(tokens), color)} {fg(f'{pct:.0f}%', color)}")

    duration_ms = (data.get("cost") or {}).get("total_duration_ms") or 0
    if duration_ms > 0:
        parts.append(muted(format_duration(duration_ms)))

    return f" {muted('◦')} ".join(parts)


def branch_info(branch: str, data: dict) -> str:
    cost = data.get("cost") or {}
    changes = []
    if cost.get("total_lines_added"):
        changes.append(f"+{cost['total_lines_added']}")
    if cost.get("total_lines_removed"):
        changes.append(f"-{cost['total_lines_removed']}")

    if not changes:
        return muted(branch)
    return f"{muted(branch)} {muted('◦')} {muted('/'.join(changes))}"


def main() -> None:
    if len(sys.argv) > 1:
        print(__doc__.strip())
        print("\nUsage: simple.py < status.json")
        return

    data = json.loads(sys.stdin.read())
    cwd = data.get("workspace", {}).get("current_dir") or os.getcwd()

    segments = [f"{fg(CLAUDE_ICON, CLAUDE_ICON_COLOR)} {claude_info(data)}"]

    branch = git_branch(cwd)
    if branch:
        segments.append(f"{fg(GIT_ICON, GIT_ICON_COLOR)} {branch_info(branch, data)}")

    user = git(cwd, "config", "user.name")
    if user:
        segments.append(f"{fg(USER_ICON, USER_ICON_COLOR)} {muted(user)}")

    print("  ".join(segments))


if __name__ == "__main__":
    main()
