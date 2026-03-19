#!/usr/bin/env bash
# Management script for the always-on Mac Mini.
set -euo pipefail

DIR="$(dirname "$0")"
PLIST_NAME="net.aaroncurry.motherbox.mini-nightly-maintenance"
PLIST_TEMPLATE="$DIR/$PLIST_NAME.plist.template"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
MINI_SH="$(cd "$DIR" && pwd)/mini.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command> [subcommand]

Management script for the Mac Mini.

Commands:
    setup                Install launchd plist and run once to trigger TCC prompts
    uninstall            Remove launchd plist
    kickstart            Manually trigger the nightly maintenance via launchd
    maintain nightly     Run nightly maintenance tasks

EOF
}

do_setup() {
    echo "==> Installing launchd plist..."
    mkdir -p "$HOME/.config/motherbox/logs"
    sed -e "s|__HOME__|$HOME|g" -e "s|__MINI_SH__|$MINI_SH|g" "$PLIST_TEMPLATE" >"$PLIST_DEST"

    # Unload first if already loaded (ignore errors)
    launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true

    launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"
    echo "==> Installed and loaded $PLIST_NAME"
    echo "    Nightly maintenance will run at 2:00 AM"

    echo "==> Running once to trigger TCC permission prompts..."
    do_kickstart
}

do_kickstart() {
    echo "==> Kickstarting $PLIST_NAME..."
    launchctl kickstart "gui/$(id -u)/$PLIST_NAME"
    echo "==> Kicked off. Check logs for output."
}

do_uninstall() {
    echo "==> Uninstalling launchd plist..."
    launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
    rm -f "$PLIST_DEST"
    echo "==> Removed $PLIST_NAME"
}

do_maintain_nightly() {
    echo "==> Syncing Obsidian vault..."
    osascript "$DIR/quit-obsidian.applescript"
    ob sync --path ~/Notes/Memex

    echo "==> Restarting Claude Desktop..."
    osascript "$DIR/restart-claude-desktop.applescript"
}

cmd="${1:-}"
subcmd="${2:-}"

case "$cmd" in
setup)
    do_setup
    ;;
kickstart)
    do_kickstart
    ;;
uninstall)
    do_uninstall
    ;;
maintain)
    case "$subcmd" in
    nightly)
        do_maintain_nightly
        ;;
    "")
        echo "Error: missing subcommand. Usage: $(basename "$0") maintain nightly" >&2
        exit 1
        ;;
    *)
        echo "Error: unknown maintain subcommand '$subcmd'" >&2
        exit 1
        ;;
    esac
    ;;
help | --help | -h)
    show_help
    ;;
"")
    show_help
    ;;
*)
    echo "Error: unknown command '$cmd'" >&2
    exit 1
    ;;
esac
