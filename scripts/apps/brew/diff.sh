#!/bin/bash

# Report drift between the managed global Brewfile and what's actually
# installed, both directions, names only:
#   Missing — declared in the Brewfile but not installed.
#   Extra   — installed but not declared.
#
# Read-only: never installs, uninstalls or upgrades anything. Runnable by hand
# or by mother. The declared set comes from `brew bundle list` (so Brewfile
# syntax is parsed by brew, not by hand); the installed set comes from brew
# directly; the two are diffed with comm. Covers formulae, casks and mas.
#
# Deliberately not `brew bundle check` (reports installed-but-outdated as
# "needs to be installed", plus dependency-graph noise) or `brew bundle
# cleanup` (tacks on a full `brew cleanup` cache/old-version pass).
set -euo pipefail

# `bundle` is in brew's AUTO_UPDATE_COMMANDS list, so the `brew bundle list`
# calls below trigger a formula-index refresh. That's pure latency here: this
# script only reports, and a fresher index cannot change what it prints. Scoped
# to this script rather than brew.env so install paths still auto-update.
# (`brew list` and `brew leaves` don't trigger it.)
export HOMEBREW_NO_AUTO_UPDATE=1

# Settings live in $XDG_CONFIG_HOME/homebrew/brew.env. dot_zshenv sets that for
# every zsh, but this script is bash and bash never reads .zshenv — it only
# inherits. HOMEBREW_XDG_CONFIG_HOME is bin/brew's documented fallback; it is
# checked second, so an inherited XDG_CONFIG_HOME still wins. See bundle.sh.
export HOMEBREW_XDG_CONFIG_HOME="$HOME/.config"

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

# Mac App Store apps are the one set brew can't hand us in comparable form:
# `brew bundle list --mas` prints only the quoted label, but `mas "Label", id: N`
# is matched on the *id* — the label is cosmetic and drifts when Apple renames an
# app. So key on the id and read the labels off both sides for display, giving
# "<id> <name>" tables. Sorting the whole line keeps the id-only cut sorted too
# (space sorts before any digit), which is what comm and join need.
declared_mas=$(sed -n 's/^mas *"\([^"]*\)" *, *id: *\([0-9][0-9]*\).*/\2 \1/p' "$BREWFILE" | sort -u)
if command -v mas >/dev/null 2>&1; then
    installed_mas=$(mas list | awk '{ id = $1; sub(/^ *[0-9]+ +/, ""); sub(/ +\([^)]*\)$/, ""); print id, $0 }' | sort -u)
else
    installed_mas=""
fi
declared_mas_ids=$(echo "$declared_mas" | cut -d' ' -f1)
installed_mas_ids=$(echo "$installed_mas" | cut -d' ' -f1)

echo "==> Missing (declared in Brewfile, not installed)"
echo "--- formulae ---"
show "$(comm -23 <(echo "$declared_formulae") <(echo "$installed_formulae"))"
echo "--- casks ---"
show "$(comm -23 <(echo "$declared_casks") <(echo "$installed_casks"))"
echo "--- mas ---"
show "$(join <(comm -23 <(echo "$declared_mas_ids") <(echo "$installed_mas_ids")) <(echo "$declared_mas"))"

echo
echo "==> Extra (installed, not declared in Brewfile)"
echo "--- formulae ---"
show "$(comm -23 <(echo "$requested_formulae") <(echo "$declared_formulae"))"
echo "--- casks ---"
show "$(comm -23 <(echo "$installed_casks") <(echo "$declared_casks"))"
echo "--- mas ---"
show "$(join <(comm -23 <(echo "$installed_mas_ids") <(echo "$declared_mas_ids")) <(echo "$installed_mas"))"
