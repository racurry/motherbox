#!/bin/bash

# Install/upgrade everything in the managed global Brewfile. Runnable by hand,
# by mother, or by the chezmoi onchange hook.
set -euo pipefail

# brew may not be on PATH when invoked outside an interactive shell.
if ! command -v brew >/dev/null 2>&1; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Bundle by explicit path. Interactive `brew bundle --global` resolves to this
# same file via XDG_CONFIG_HOME from .zshrc, but unattended runs (chezmoi
# apply, mother) can't rely on that being set.
BREWFILE="${HOME}/.config/homebrew/Brewfile"

# Entries that can't install without a human (Mac App Store apps, sudo/GUI
# casks) are skipped via HOMEBREW_BUNDLE_*_SKIP, which `mother` sets in the
# environment for unattended runs. This script stays unaware of that policy.
#
# `brew bundle` installs everything it can and exits non-zero if any single
# entry fails; that exit code is passed through so callers decide whether a
# partial failure is fatal.
exec brew bundle --file="${BREWFILE}"
