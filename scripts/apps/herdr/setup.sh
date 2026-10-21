#!/bin/bash
# Register Motherbox's Herdr plugins after brew, mise, and native installs.
set -euo pipefail

case "${1:-}" in
    -h|--help)
        cat <<'EOF'
Usage: setup.sh [--help]

Link Motherbox's TTT plugin and install the configured Herdr Palette revision
when missing or different. Register the TTT plugin and reload running sessions.
Requires Herdr's native install, TTT, Python 3, jq, Git, and Rust/Cargo.
Run after chezmoi has applied the configs and installed those dependencies.
Does not start, stop, or restart Herdr sessions.
EOF
        exit 0
        ;;
    "") ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
esac

plugin_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/editor" && pwd)"
export CARGO_HOME="${CARGO_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/rustup}"
# chezmoi scripts do not load interactive zsh's PATH or mise activation.
export PATH="$HOME/.local/bin:$CARGO_HOME/bin:${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:/opt/homebrew/bin:$PATH"

for tool in herdr ttt python3 jq git cargo; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Missing $tool; complete the brew, mise, and native installer steps first." >&2
        exit 1
    fi
done

# Keep the same reviewed palette source on each computer.
palette_ref="0478a908afd4f0775d8165765dcdc7d70a6e5ac1"
palette="$(herdr plugin list --plugin ramarivera.palette --json)"
if ! jq -e --arg ref "$palette_ref" '
    .result.plugins[] | select(.plugin_id == "ramarivera.palette"
        and .source.kind == "github" and .source.owner == "ramarivera"
        and .source.repo == "herdr-palette" and .source.resolved_commit == $ref)
' <<< "$palette" >/dev/null; then
    herdr plugin install ramarivera/herdr-palette --ref "$palette_ref" --yes
fi
herdr plugin link "$plugin_dir" --enabled
herdr config check

# Reload only existing servers. An empty session list is normal on a new Mac.
sessions="$(herdr session list --json)"
while IFS= read -r session; do
    if [[ "$session" == default ]]; then
        herdr server reload-config
    else
        herdr --session "$session" server reload-config
    fi
done < <(jq -r '.sessions[] | select(.running) | .name' <<< "$sessions")
