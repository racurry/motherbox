autoload -Uz add-zsh-hook

# fpath additions must precede compinit.
fpath=("$HOME/.grok/completions/zsh" $fpath)

autoload -Uz compinit
compinit -C

# Cortex CLI keeps its completion in ~/.zsh; its loader handles post-compinit.
if [ -f "$HOME/.zsh/completions/cortex.zsh" ]; then
	source "$HOME/.zsh/completions/cortex.zsh"
fi

# Source completion/navigation plugins from Homebrew when installed.
if [ -f "$BREW_PREFIX/share/fzf-tab/fzf-tab.zsh" ]; then
	source "$BREW_PREFIX/share/fzf-tab/fzf-tab.zsh"
fi

if [ -f "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]; then
	source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
fi
