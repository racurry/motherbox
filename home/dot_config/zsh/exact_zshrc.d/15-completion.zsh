autoload -Uz add-zsh-hook
autoload -Uz compinit
compinit -C

# Source completion/navigation plugins from Homebrew when installed.
if [ -f "$BREW_PREFIX/share/fzf-tab/fzf-tab.zsh" ]; then
	source "$BREW_PREFIX/share/fzf-tab/fzf-tab.zsh"
fi

if [ -f "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]; then
	source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
fi
