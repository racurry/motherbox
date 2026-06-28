# Use the pure prompt.
autoload -U promptinit; promptinit
prompt pure

autoload -Uz compinit && compinit

# Source Homebrew-installed zsh plugins.
source_brew_plugin() {
  [ -f "$BREW_PREFIX/$1" ] && source "$BREW_PREFIX/$1"
}

source_brew_plugin "share/fzf-tab/fzf-tab.zsh"
source_brew_plugin "opt/fzf/shell/key-bindings.zsh"
source_brew_plugin "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

unset -f source_brew_plugin

# Set terminal title to current directory using ~ for home.
precmd() { print -Pn "\e]2;%~\a" }
