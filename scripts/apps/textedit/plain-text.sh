#!/bin/bash
# Make TextEdit open new documents as plain text.
set -euo pipefail

show_help() {
	cat <<'EOF_HELP'
Usage: plain-text.sh [OPTIONS]

Set TextEdit's default document format to plain text.

TextEdit keeps its preferences inside its app container, which macOS only
lets a terminal modify once that terminal has Full Disk Access (System
Settings > Privacy & Security > Full Disk Access). Grant it, relaunch the
terminal, then run this script. Safe to rerun.

OPTIONS:
  -h, --help  Show this help
EOF_HELP
}

case "${1:-}" in
-h | --help)
	show_help
	exit 0
	;;
"") ;;
*)
	echo "Unknown option: $1" >&2
	show_help >&2
	exit 1
	;;
esac

if ! defaults write com.apple.TextEdit RichText -int 0; then
	echo "Could not write TextEdit preferences. Give this terminal Full Disk Access, relaunch it, and rerun." >&2
	exit 1
fi

killall TextEdit 2>/dev/null || true
echo "TextEdit defaults to plain text"
