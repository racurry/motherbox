#!/bin/bash
# Open a second Herdr window showing one layout.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: window.sh <layout>

Open a second Herdr window showing layout <layout>. The main window keeps its
own layout, and both windows show the same spaces and agents.

A layout belongs to a Herdr home, so the window is a second Herdr process whose
home is ~/.config/herdr-app-windows/layout-<layout>/. That home is a copy of the
main home's mods, layouts, themes, keys and settings, made each time the window
opens. Reach the window with:

    HERDR_APP_HOME=~/.config/herdr-app-windows/layout-<layout> herdr-app ...
EOF
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    "") usage >&2; exit 2 ;;
esac

name="$1"
main="$HOME/.config/herdr-app"
home="$HOME/.config/herdr-app-windows/layout-$name"

if [[ ! -f "$main/layouts/$name.json" ]]; then
    echo "No layout named $name in $main/layouts" >&2
    exit 1
fi

if nc -w 2 -U "$home/herdr-app.sock" </dev/null 2>/dev/null; then
    echo "The $name window is already open"
    exit 0
fi

mkdir -p "$home"
for dir in mods layouts themes; do
    [[ -d "$main/$dir" ]] && rsync -aL --delete "$main/$dir/" "$home/$dir/"
done
for file in keys.json settings.json programs.json; do
    [[ -f "$main/$file" ]] && cp -f "$main/$file" "$home/$file"
done
printf '{"layout":"%s","frame.welcomed":"finished"}\n' "$name" > "$home/shared.json"

open -n -b dev.herdr.app --env "HERDR_APP_HOME=$home"
