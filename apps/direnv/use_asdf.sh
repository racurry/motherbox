# shellcheck shell=bash
# ~/.config/direnv/lib/use_asdf.sh  (recommended)
# or paste into the top of your project's .envrc

use_asdf() {
    # Ensure .tool-versions changes trigger reloads
    watch_file .tool-versions

    # Locate asdf and its init script (Homebrew vs ~/.asdf install)
    local asdf_sh=""
    if command -v asdf >/dev/null 2>&1; then
        # Homebrew installs asdf's init script here:
        if [ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]; then
            asdf_sh="/opt/homebrew/opt/asdf/libexec/asdf.sh"
        # Classic installer puts it here:
        elif [ -f "$HOME/.asdf/asdf.sh" ]; then
            asdf_sh="$HOME/.asdf/asdf.sh"
        fi
    fi

    if [ -n "$asdf_sh" ]; then
        # shellcheck source=/dev/null
        . "$asdf_sh"
    else
        echo "use_asdf: couldn't find asdf init script; is asdf installed?" >&2
        return 1
    fi

    # Ensure shims are on PATH for direnv's subshell
    export ASDF_DIR="${ASDF_DIR:-$HOME/.asdf}"
    if [ -d "$ASDF_DIR/shims" ]; then
        PATH_add "$ASDF_DIR/shims"
    fi

    # Optional: recognize legacy version files alongside .tool-versions
    # export ASDF_LEGACY_FILE=".tool-versions"

    # Optional: auto-install missing runtimes on enter (fast no-op if present)
    # comment this block out if you don't want installs happening in direnv
    if command -v asdf >/dev/null 2>&1 && [ -f .tool-versions ]; then
        asdf install >/dev/null 2>&1 || true
    fi
}
