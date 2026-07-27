#!/bin/bash
# Layer 1 — Claude Code CLI bootstrap.
#
# Run by chezmoi during `chezmoi apply`, after 10-brew/20-mise. Thin hook: the
# real logic lives in scripts/apps/claude-code/install.sh so it can also be run
# by hand. run_once (not onchange) because Claude Code self-updates after this
# initial install; rerun manually by clearing the chezmoi state if you ever need
# a fresh install.
set -euo pipefail

echo "==> Layer 1: Claude Code"
"$CHEZMOI_WORKING_TREE/scripts/apps/claude-code/install.sh"
