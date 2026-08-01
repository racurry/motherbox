#!/bin/bash

# launchd agents — (re)load the managed user agents.
#
# chezmoi writes the plists under ~/Library/LaunchAgents, but writing the file
# does not load it — only `launchctl bootstrap` does. Triggered by chezmoi via
# home/.chezmoiscripts/run_onchange_after_50-launchagents.sh.tmpl whenever a
# plist source or this script changes; also runnable by hand at any time.
set -euo pipefail

show_help() {
    cat <<'EOF'
Usage: launchagents.sh [LABEL...] [--help]

Reload launchd user agents: bootout (ignoring "not loaded") then bootstrap the
matching plist in ~/Library/LaunchAgents. With no arguments, reloads every
agent managed by this repo. Idempotent.
EOF
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
esac

# The agents this repo manages. Each runs on every machine; the job itself
# branches on the machine name the plist passes it.
LABELS=(net.aaroncurry.motherbox.nightly-maintenance)
if [[ $# -gt 0 ]]; then
    LABELS=("$@")
fi

uid=$(id -u)
for label in "${LABELS[@]}"; do
    plist="$HOME/Library/LaunchAgents/${label}.plist"
    if [[ ! -f "$plist" ]]; then
        echo "Plist not found: $plist" >&2
        exit 1
    fi

    echo "==> launchd: reloading $label"
    launchctl bootout "gui/${uid}/${label}" 2>/dev/null || true
    launchctl bootstrap "gui/${uid}" "$plist"
done
