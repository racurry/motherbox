#!/bin/bash

# Report drift between the managed global Brewfile and what's actually
# installed, both directions, names only:
#   Missing — declared in the Brewfile but not installed.
#   Extra   — installed but not declared.
#
# Read-only: never installs, uninstalls or upgrades anything. Runnable by hand
# or by mother. The declared set comes from `brew bundle list` (so Brewfile
# syntax is parsed by brew, not by hand); the installed set comes from brew
# directly; the two are diffed with comm. Covers formulae and casks.
#
# Deliberately not `brew bundle check` (reports installed-but-outdated as
# "needs to be installed", plus dependency-graph noise) or `brew bundle
# cleanup` (tacks on a full `brew cleanup` cache/old-version pass).
set -euo pipefail

# brew may not be on PATH when invoked outside an interactive shell.
if ! command -v brew >/dev/null 2>&1; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Same file bundle.sh installs from; interactive `brew bundle --global` resolves
# here too via XDG_CONFIG_HOME from .zshrc.
BREWFILE="$HOME/.config/homebrew/Brewfile"

# Print an indented list, or "(none)" when the set is empty.
show() {
    if [[ -n "$1" ]]; then
        echo "  ${1//$'\n'/$'\n'  }"
    else
        echo "  (none)"
    fi
}

# One sorted list per set. `installed_formulae` is everything (a declared
# formula present only as a dependency still counts as installed, so it's not
# "missing"); `requested_formulae` is only the leaves the user asked for, so the
# "extra" side doesn't flag every transitive dependency.
declared_formulae=$(brew bundle list --file="$BREWFILE" --formula | sort -u)
declared_casks=$(brew bundle list --file="$BREWFILE" --cask | sort -u)
installed_formulae=$(brew list --formula | sort -u)
installed_casks=$(brew list --cask | sort -u)
requested_formulae=$(brew leaves --installed-on-request | sort -u)

echo "==> Missing (declared in Brewfile, not installed)"
echo "--- formulae ---"
show "$(comm -23 <(echo "$declared_formulae") <(echo "$installed_formulae"))"
echo "--- casks ---"
show "$(comm -23 <(echo "$declared_casks") <(echo "$installed_casks"))"

echo
echo "==> Extra (installed, not declared in Brewfile)"
echo "--- formulae ---"
show "$(comm -23 <(echo "$requested_formulae") <(echo "$declared_formulae"))"
echo "--- casks ---"
show "$(comm -23 <(echo "$installed_casks") <(echo "$declared_casks"))"
