#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Transform
# @raycast.mode silent
# @raycast.icon 🔧
# @raycast.packageName Text Utils
# @raycast.argument1 { "type": "dropdown", "placeholder": "Transform", "data": [{"title": "Sort A→Z", "value": "sort"}, {"title": "Sort Z→A", "value": "sort-reverse"}, {"title": "Dedupe", "value": "dedupe"}, {"title": "Reverse", "value": "reverse"}, {"title": "Shuffle", "value": "shuffle"}, {"title": "UPPERCASE", "value": "upper"}, {"title": "lowercase", "value": "lower"}, {"title": "Trim", "value": "trim"}] }

osascript -e 'tell application "System Events" to keystroke "c" using command down'
sleep 0.1

case "$1" in
  sort)         result=$(pbpaste | sort -df) ;;
  sort-reverse) result=$(pbpaste | sort -drf) ;;
  dedupe)       result=$(pbpaste | awk '!seen[$0]++') ;;
  reverse)      result=$(pbpaste | tail -r) ;;
  shuffle)      result=$(pbpaste | sort -R) ;;
  upper)        result=$(pbpaste | tr '[:lower:]' '[:upper:]') ;;
  lower)        result=$(pbpaste | tr '[:upper:]' '[:lower:]') ;;
  trim)         result=$(pbpaste | sed 's/[[:space:]]*$//') ;;
  *)            echo "Unknown transform: $1"; exit 1 ;;
esac

printf '%s' "$result" | pbcopy
osascript -e 'tell application "System Events" to keystroke "v" using command down'
