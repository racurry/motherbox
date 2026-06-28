# Shell convenience.
alias rezsh='source "${ZDOTDIR:-$HOME/.config/zsh}/.zshrc"'

# Motherbox repo shortcut.
alias motherbox='cd "$MOTHERBOX_ROOT"'

# Enhanced and tool overwrites.
command -v bat >/dev/null 2>&1 && alias cat='bat'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza -a'
  alias tree='eza --tree'
else
  alias ls="ls -aG"
fi

# Ruby aliases.
alias be="bundle exec"
alias rake="noglob rake"

# Directory navigation shortcuts.
alias pd='pushd'
alias pp='popd'
alias dirs='dirs -v'

# Say the magic word.
alias please='sudo $(fc -ln -1)'

# Claude Code.
alias cc='claude'
alias ccup='claude upgrade'
alias ccdanger='claude --allow-dangerously-skip-permissions'
alias ccc='claude --continue'
alias ccr='claude --resume'
alias ccp='claude --print'

# Doin things.
alias c='clear'

# Git shorthands.
alias gst='git status'
alias gaco='git aco'
alias gpub='git pub'
alias greup='git reup'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcob='git checkout -b'
alias gdff='git diff'
alias grbp='git rebase-and-push'

# Chezmoi shorthands.
alias cz=chezmoi
alias czst='chezmoi status'
alias czap='chezmoi apply'
