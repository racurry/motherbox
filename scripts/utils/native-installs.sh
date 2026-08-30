#!/bin/bash

# First-party installers for the CLIs that own their own install and updates,
# per docs/tool-responsibility.md. Runnable by hand, by mother, or by the
# chezmoi onchange hook.
set -euo pipefail

ALL_APPS=(claude-code codex antigravity atuin rustup)

show_help() {
    cat <<'EOF'
Usage: native-installs.sh [APP...] [--help]

Run the official installer for each APP. With no APP, runs all of them:
claude-code, codex, antigravity, atuin, rustup.

  claude-code   No-op when `claude` is present — the CLI self-updates.
  codex         Installs or updates; the installer owns ~/.codex and
                exposes the binary at ~/.local/bin/codex.
  antigravity   No-op when `agy` is present — the CLI self-updates in the
                background. Installs to ~/.local/bin/agy.
  atuin         No-op when `atuin` is present. Installs to ~/.atuin/bin;
                shell init comes from the managed zshrc.d fragment.
  rustup        No-op when `rustup` is present — `rustup update` owns
                updates. Installs rustup, cargo, and the stable toolchain
                into $CARGO_HOME and $RUSTUP_HOME; shell init comes from
                the managed zshrc.d fragment.
EOF
}

installed() {
    command -v "$1" >/dev/null 2>&1
}

install_claude_code() {
    if installed claude || [[ -x "$HOME/.local/bin/claude" ]]; then
        echo "==> Claude Code already installed; skipping"
        return 0
    fi

    echo "==> Installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash
}

install_codex() {
    echo "==> Installing/updating Codex CLI"
    curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
}

install_antigravity() {
    if installed agy || [[ -x "$HOME/.local/bin/agy" ]]; then
        echo "==> Antigravity CLI already installed; skipping"
        return 0
    fi

    # The installer's last step runs `agy install`, which appends a PATH export
    # to ~/.zprofile and ~/.profile. Both are inert here — ZDOTDIR moves zsh's
    # profile to $ZDOTDIR/.zprofile, and the managed zshrc.d fragment already
    # puts ~/.local/bin on PATH.
    echo "==> Installing Antigravity CLI"
    curl -fsSL https://antigravity.google/cli/install.sh | bash
}

install_atuin() {
    if installed atuin || [[ -x "$HOME/.atuin/bin/atuin" ]]; then
        echo "==> Atuin already installed; skipping"
        return 0
    fi

    # setup.atuin.sh appends its own `atuin init zsh` line to $ZDOTDIR/.zshrc,
    # which chezmoi owns and rewrites on the next apply. Harmless, but it is why
    # this only ever runs on a machine without Atuin.
    echo "==> Installing Atuin"
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive
}

install_rustup() {
    # Bash never reads ~/.zshenv, so mirror the XDG locations it exports.
    local xdg_data="${XDG_DATA_HOME:-$HOME/.local/share}"
    export CARGO_HOME="${CARGO_HOME:-$xdg_data/cargo}"
    export RUSTUP_HOME="${RUSTUP_HOME:-$xdg_data/rustup}"

    if installed rustup || [[ -x "$CARGO_HOME/bin/rustup" ]]; then
        echo "==> rustup already installed; skipping"
        return 0
    fi

    # --no-modify-path keeps rustup out of ~/.zshenv, which chezmoi owns; the
    # managed zshrc.d fragment puts $CARGO_HOME/bin on PATH instead.
    echo "==> Installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
}

case "${1:-}" in
-h | --help | help)
    show_help
    exit 0
    ;;
esac

apps=("$@")
if [[ ${#apps[@]} -eq 0 ]]; then
    apps=("${ALL_APPS[@]}")
fi

for app in "${apps[@]}"; do
    case "$app" in
    claude-code) install_claude_code ;;
    codex) install_codex ;;
    antigravity) install_antigravity ;;
    atuin) install_atuin ;;
    rustup) install_rustup ;;
    *)
        printf "Unknown app: %s\n\n" "$app" >&2
        show_help >&2
        exit 1
        ;;
    esac
done
