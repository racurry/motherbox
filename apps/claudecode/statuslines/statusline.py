#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Claude Code two-line status line.

Line 1: Work context — git branch (clickable), worktree, agent name
Line 2: Session stats — context bar, cost, duration, lines changed
"""

# =============================================================================
# STATUS HOOK INPUT SCHEMA (updated for v2.1+)
# =============================================================================
# Claude Code passes JSON via stdin. Key fields:
#
#   model.id, model.display_name
#   workspace.current_dir, workspace.project_dir, workspace.added_dirs
#   cost.total_cost_usd, total_duration_ms, total_api_duration_ms
#   cost.total_lines_added, total_lines_removed
#   context_window.used_percentage, remaining_percentage
#   context_window.current_usage.input_tokens (+ cache variants)
#   context_window.context_window_size
#   vim.mode (NORMAL/INSERT, only when enabled)
#   agent.name (only with --agent)
#   worktree.name, worktree.path, worktree.branch
#   exceeds_200k_tokens (bool)
# =============================================================================

import argparse
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass

# =============================================================================
# ANSI STYLING
# =============================================================================
_RESET = "\033[0m"

_STYLES = {
    "bold": "\033[1m",
    "dim": "\033[2m",
    "italic": "\033[3m",
}

_FG = {
    "black": "\033[30m",
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "blue": "\033[34m",
    "magenta": "\033[35m",
    "cyan": "\033[36m",
    "white": "\033[37m",
    "bright_black": "\033[90m",
    "bright_red": "\033[91m",
    "bright_green": "\033[92m",
    "bright_yellow": "\033[93m",
    "bright_blue": "\033[94m",
    "bright_magenta": "\033[95m",
    "bright_cyan": "\033[96m",
    "bright_white": "\033[97m",
}

_BG = {
    "black": "\033[40m",
    "red": "\033[41m",
    "green": "\033[42m",
    "yellow": "\033[43m",
    "blue": "\033[44m",
    "magenta": "\033[45m",
    "cyan": "\033[46m",
    "white": "\033[47m",
    "bright_black": "\033[100m",
    "bright_red": "\033[101m",
    "bright_green": "\033[102m",
    "bright_yellow": "\033[103m",
    "bright_blue": "\033[104m",
    "bright_magenta": "\033[105m",
    "bright_cyan": "\033[106m",
    "bright_white": "\033[107m",
}


def _color_code(color: str | int, bg: bool = False) -> str:
    """Resolve a color to an ANSI escape. Accepts a named color or a 256-color int."""
    if isinstance(color, int):
        return f"\033[{'48' if bg else '38'};5;{color}m"
    return (_BG if bg else _FG)[color]


def styled(
    text: str,
    fg: str | int | None = None,
    bg: str | int | None = None,
    style: str | None = None,
) -> str:
    codes = []
    if style:
        codes.append(_STYLES[style])
    if fg is not None:
        codes.append(_color_code(fg))
    if bg is not None:
        codes.append(_color_code(bg, bg=True))
    if not codes:
        return text
    return f"{''.join(codes)}{text}{_RESET}"


def osc8_link(url: str, text: str) -> str:
    """Wrap text in an OSC 8 hyperlink (clickable in iTerm2, Ghostty, etc.)."""
    return f"\033]8;;{url}\033\\{text}\033]8;;\033\\"


# =============================================================================
# SCHEMA DISCOVERY LOGGING
# =============================================================================
LOG_PATH = ".tmp/claude_status_samples.jsonl"
LOG_SAMPLES = 10


def log_stdin_sample(raw_input: str) -> None:
    import datetime

    try:
        sample_count = 0
        if os.path.exists(LOG_PATH):
            with open(LOG_PATH) as f:
                sample_count = sum(1 for _ in f)
        if sample_count < LOG_SAMPLES:
            with open(LOG_PATH, "a") as f:
                entry = {
                    "timestamp": datetime.datetime.now().isoformat(),
                    "data": json.loads(raw_input),
                }
                f.write(json.dumps(entry) + "\n")
    except Exception:
        pass


# =============================================================================
# DATA
# =============================================================================
@dataclass
class GitInfo:
    branch: str = "detached"
    ahead: int = 0
    behind: int = 0
    has_upstream: bool = False
    has_staged: bool = False
    has_unstaged: bool = False
    remote_url: str = ""
    pr_url: str = ""


@dataclass
class SessionStats:
    duration_ms: int = 0
    lines_added: int = 0
    lines_removed: int = 0
    context_pct: float = 0.0
    context_tokens: int = 0
    context_max: int = 200_000


# =============================================================================
# DATA COLLECTION
# =============================================================================
def get_git_info(cwd: str) -> GitInfo | None:
    """Get git state and remote URL in parallel subprocess calls."""
    try:
        status_result = subprocess.run(
            ["git", "-C", cwd, "status", "--porcelain=v2", "--branch"],
            capture_output=True,
            text=True,
            timeout=3,
        )
    except subprocess.TimeoutExpired:
        return None
    if status_result.returncode != 0:
        return None

    info = GitInfo()

    for line in status_result.stdout.splitlines():
        if line.startswith("# branch.head "):
            info.branch = line[14:] or "detached"
        elif line.startswith("# branch.upstream "):
            info.has_upstream = True
        elif line.startswith("# branch.ab "):
            parts = line[12:].split()
            if len(parts) >= 2:
                info.ahead = int(parts[0].lstrip("+"))
                info.behind = abs(int(parts[1]))
        elif line and not line.startswith("#"):
            if line.startswith("? "):
                info.has_unstaged = True
            elif len(line) > 4:
                xy = line[2:4]
                if xy[0] != ".":
                    info.has_staged = True
                if xy[1] != ".":
                    info.has_unstaged = True

    # Get remote URL for clickable links
    try:
        remote_result = subprocess.run(
            ["git", "-C", cwd, "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if remote_result.returncode == 0:
            info.remote_url = remote_result.stdout.strip()
    except subprocess.TimeoutExpired:
        pass

    # Check for open PR (cached to avoid API calls on every update)
    info.pr_url = _get_cached_pr_url(cwd, info.branch)

    return info


PR_CACHE_DIR = ".tmp"
PR_CACHE_TTL = 60  # seconds


def _get_cached_pr_url(cwd: str, branch: str) -> str:
    """Get PR URL for current branch, cached to disk for PR_CACHE_TTL seconds."""
    cache_file = os.path.join(PR_CACHE_DIR, f"pr_cache_{branch}")
    try:
        if os.path.exists(cache_file):
            age = time.time() - os.path.getmtime(cache_file)
            if age < PR_CACHE_TTL:
                with open(cache_file) as f:
                    return f.read().strip()
    except Exception:
        pass

    # Cache miss or stale — query gh CLI
    pr_url = ""
    try:
        result = subprocess.run(
            ["gh", "pr", "view", "--json", "url", "-q", ".url"],
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=3,
        )
        if result.returncode == 0:
            pr_url = result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    # Write cache (even empty — avoids re-querying branches with no PR)
    try:
        os.makedirs(PR_CACHE_DIR, exist_ok=True)
        with open(cache_file, "w") as f:
            f.write(pr_url)
    except Exception:
        pass

    return pr_url


def get_session_stats(data: dict) -> SessionStats:
    """Extract all session stats from the status hook JSON."""
    stats = SessionStats()

    cost = data.get("cost", {})
    stats.duration_ms = cost.get("total_duration_ms", 0) or 0
    stats.lines_added = cost.get("total_lines_added", 0) or 0
    stats.lines_removed = cost.get("total_lines_removed", 0) or 0

    ctx = data.get("context_window", {})
    stats.context_pct = ctx.get("used_percentage", 0.0) or 0.0
    stats.context_max = ctx.get("context_window_size", 200_000) or 200_000

    # Get token count from current_usage
    current_usage = ctx.get("current_usage")
    if current_usage:
        stats.context_tokens = (
            (current_usage.get("input_tokens", 0) or 0)
            + (current_usage.get("cache_creation_input_tokens", 0) or 0)
            + (current_usage.get("cache_read_input_tokens", 0) or 0)
        )

    return stats


# =============================================================================
# FORMATTING HELPERS
# =============================================================================
def format_tokens(tokens: int) -> str:
    if tokens >= 1_000_000:
        return f"{tokens / 1_000_000:.1f}M"
    if tokens >= 1000:
        return f"{tokens // 1000}k"
    return str(tokens)


def format_duration(ms: int) -> str:
    total_seconds = ms // 1000
    if total_seconds < 60:
        return f"{total_seconds}s"
    minutes = total_seconds // 60
    if minutes < 60:
        return f"{minutes}m"
    hours = minutes // 60
    remaining_min = minutes % 60
    return f"{hours}h{remaining_min:02d}m"


def context_color(pct: float) -> int:
    if pct >= 85:
        return ALERT_COLOR
    if pct >= 70:
        return ATTENTION_COLOR
    return MUTE_COLOR


def progress_bar(pct: float, width: int = 10) -> str:
    """Render a visual progress bar: ▓▓▓▓░░░░░░"""
    filled = round(pct / 100 * width)
    filled = max(0, min(width, filled))
    empty = width - filled
    if pct >= 70:
        return styled("▓" * filled, fg=context_color(pct)) + styled("░" * empty, fg=MUTE_COLOR)
    return styled("▓" * filled, fg=MUTE_COLOR) + styled("░" * empty, fg=MUTE_COLOR)


def github_url_from_remote(remote_url: str) -> str | None:
    """Convert a git remote URL to a GitHub HTTPS base URL."""
    url = remote_url
    if url.startswith("git@github.com:"):
        url = url.replace("git@github.com:", "https://github.com/")
    if url.endswith(".git"):
        url = url[:-4]
    if "github.com" in url:
        return url
    return None


# =============================================================================
# THEME
# =============================================================================
# 256-color theme: monochrome purple with color shifts for severity.
#   Calm (base):      140 — soft lavender, default for everything
#   Attention:         213 — warm bright pink-purple, "you should know"
#   Alert:             167 — dim red leaning purple, "something is wrong"
# Preview: for c in 140 213 167; do printf "\033[38;5;${c}m%-4s sample\033[0m\n" "$c"; done
MUTE_COLOR = 140
ATTENTION_COLOR = 213
ALERT_COLOR = 167
PILL_BG = 236  # neutral dark gray for content segments
GIT_ICON_BG = 28  # GitHub logo background (dark green)
GIT_STATUS_BG = 34  # git status indicators background (brighter green)
CLAUDE_ICON_BG = 208  # Claude logo background (orange)
SEP = styled(" │ ", fg=MUTE_COLOR)
ARROW = "\ue0b0"  # powerline right-pointing triangle


def muted(text: str) -> str:
    return styled(text, fg=MUTE_COLOR)


def powerline_segments(segments: list[tuple[int, str]]) -> str:
    """Render a list of (bg_color, content) as classic powerline segments.

    Each segment flows into the next with an angled arrow separator.
    Content can contain its own fg ANSI codes; inner resets are patched
    so the segment bg persists.
    """
    out = ""
    for i, (bg, content) in enumerate(segments):
        bg_code = _color_code(bg, bg=True)
        # Patch inner resets so bg persists through pre-styled content
        inner = content.replace(_RESET, _RESET + bg_code)

        if i == 0:
            # First segment: square left edge
            out += f"{bg_code}{inner} "
        else:
            # Arrow from previous bg into this bg
            prev_bg = segments[i - 1][0]
            out += styled(ARROW, fg=prev_bg, bg=bg)
            out += f"{bg_code}{inner} "

        # Last segment: arrow into terminal default
        if i == len(segments) - 1:
            out += f"{_RESET}{styled(ARROW, fg=bg)}"

    return out


# =============================================================================
# FORMATTING
# =============================================================================
def format_statusline(
    git: GitInfo | None,
    model: str,
    stats: SessionStats,
    data: dict,
) -> str:
    """Build the full powerline statusline."""
    segments: list[tuple[int, str]] = []

    # --- Segment 1: GitHub icon (dark green bg) ---
    if git:
        gh_url = github_url_from_remote(git.remote_url) if git.remote_url else None
        gh_icon = "\uf09b"
        if gh_url:
            gh_icon = osc8_link(gh_url, styled(gh_icon, fg="white"))
        else:
            gh_icon = styled(gh_icon, fg="white")
        segments.append((GIT_ICON_BG, f" {gh_icon}"))

    # --- Segment 2: Git status indicators (brighter green bg) ---
    if git:
        status_parts: list[str] = []
        # PR
        if git.pr_url:
            status_parts.append(osc8_link(git.pr_url, styled("\U000f062c", fg="white")))
        # Sync
        if git.ahead:
            status_parts.append(styled(f"↑{git.ahead}", fg="white"))
        if git.behind:
            status_parts.append(styled(f"↓{git.behind}", fg="white"))
        # Dirty state
        if git.has_staged:
            status_parts.append(styled("●", fg="white"))
        if git.has_unstaged:
            status_parts.append(styled("○", fg="white"))
        # No upstream
        if git.branch != "detached" and not git.has_upstream:
            status_parts.append(styled("⚠", fg="white"))

        if status_parts:
            segments.append((GIT_STATUS_BG, f" {' '.join(status_parts)}"))

    # --- Segment 3: Git info (dark bg) ---
    if git:
        gh_url = github_url_from_remote(git.remote_url) if git.remote_url else None
        if gh_url and git.branch != "detached":
            branch_url = f"{gh_url}/tree/{git.branch}"
            branch = osc8_link(branch_url, muted(git.branch))
        else:
            branch = muted(git.branch)

        git_parts = [f" {branch}"]

        # Lines changed (in parens after branch name)
        if stats.lines_added or stats.lines_removed:
            changes = []
            if stats.lines_added:
                changes.append(f"+{stats.lines_added}")
            if stats.lines_removed:
                changes.append(f"-{stats.lines_removed}")
            git_parts.append(muted(f"({'/'.join(changes)})"))

        # Worktree
        worktree = data.get("worktree")
        if worktree:
            wt_name = worktree.get("name", "")
            if wt_name:
                git_parts.append(SEP)
                git_parts.append(muted(wt_name))

        segments.append((PILL_BG, " ".join(git_parts)))

    # --- Segment 3: Claude icon (orange bg) ---
    segments.append((CLAUDE_ICON_BG, f" {styled('❋', fg='white')}"))

    # --- Segment 4: Claude info (dark bg) ---
    claude_parts = [f" {muted(model)}"]

    # Agent
    agent = data.get("agent")
    if agent:
        agent_name = agent.get("name", "")
        if agent_name:
            claude_parts.append(SEP)
            claude_parts.append(muted(agent_name))

    # Context bar
    bar = progress_bar(stats.context_pct, width=12)
    pct_str = f"{stats.context_pct:.0f}%"
    tokens_str = format_tokens(stats.context_tokens)
    claude_parts.append(SEP)
    if stats.context_pct >= 70:
        ctx_col = context_color(stats.context_pct)
        claude_parts.append(f"{bar} {styled(pct_str, fg=ctx_col)} {muted(tokens_str)}")
    else:
        claude_parts.append(f"{bar} {muted(pct_str)} {muted(tokens_str)}")

    # Duration
    if stats.duration_ms > 0:
        claude_parts.append(SEP)
        claude_parts.append(muted(format_duration(stats.duration_ms)))

    segments.append((PILL_BG, " ".join(claude_parts)))

    return powerline_segments(segments)


# =============================================================================
# MAIN
# =============================================================================
def main() -> None:
    parser = argparse.ArgumentParser(description="Claude Code status line")
    parser.add_argument(
        "--log",
        action="store_true",
        help=f"Log stdin samples to {LOG_PATH} for schema discovery",
    )
    args = parser.parse_args()

    raw_input = sys.stdin.read()
    if args.log:
        log_stdin_sample(raw_input)
    data = json.loads(raw_input)

    cwd = data.get("workspace", {}).get("current_dir", os.getcwd())
    model = data.get("model", {}).get("display_name", "unknown")

    git = get_git_info(cwd)
    stats = get_session_stats(data)

    print(format_statusline(git, model, stats, data))


if __name__ == "__main__":
    main()
