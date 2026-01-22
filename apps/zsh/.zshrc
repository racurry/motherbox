# ============================================================================
# PACKAGE MANAGERS & TOOL SETUP
# ============================================================================

# Homebrew and ASDF setup
# Ensure Homebrew is on the path and asdf is sourced
# (Order matters as asdf is installed via Homebrew)
eval "$(/opt/homebrew/bin/brew shellenv)"

# Set Homebrew prefix for reuse throughout shell and exported for subprocesses
export BREW_PREFIX=$(brew --prefix)

. $BREW_PREFIX/opt/asdf/libexec/asdf.sh

# Add asdf completions
fpath=(${ASDF_DIR}/completions $fpath)

# Source Homebrew-installed zsh plugins
source_brew_plugin() {
  [ -f "$BREW_PREFIX/$1" ] && source "$BREW_PREFIX/$1"
}

source_brew_plugin "opt/fzf/shell/completion.zsh"
source_brew_plugin "opt/fzf/shell/key-bindings.zsh"
source_brew_plugin "share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source_brew_plugin "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"  # Must be last

unset -f source_brew_plugin

# Only auto-update Homebrew once per day (86400 seconds)
export HOMEBREW_AUTO_UPDATE_SECS=86400
export HOMEBREW_NO_ENV_HINTS=1

# Initialize direnv if available
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# ============================================================================
# SHELL APPEARANCE & BEHAVIOR
# ============================================================================

# Use the pure prompt
autoload -U promptinit; promptinit
prompt pure

# Set terminal title to current directory (using ~ for home)
precmd() { print -Pn "\e]2;%~\a" }

# The fuck
eval $(thefuck --alias)

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR='code'

# Keep less from paginating unless it needs to
export LESS="-FRXK"

# Hug the face
export HF_HOME="$HOME/.cache/huggingface"

# OpenSCAD custom library path (avoids cluttering ~/Documents)
export OPENSCADPATH="$HOME/OpenSCAD/Libraries"

# Anything local that doesn't go in git goes in here.  
# Eg, global secrets, etc
[[ -f ~/.local.zshrc ]] && source ~/.local.zshrc

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================

HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=50000
HISTDUP=erase # Erase duplicates in the history file
setopt appendhistory # Append history to the history file (no overwriting)
setopt sharehistory # Share history across terminals
setopt incappendhistory # Immediately append to the history file, not just when a term is killed
unsetopt nomatch # Don't throw an error if there are no matches, just do the right thing

# Bind up arrow to FZF history search (uses typed prefix as initial filter)
bindkey '^[[A' fzf-history-widget

# ============================================================================
# APPLICATION-SPECIFIC SETUP
# ============================================================================

# Set up NPM_TOKEN if .npmrc exists
if [ -f ~/.npmrc ]; then
  export NPM_TOKEN=`sed -n -e '/_authToken/ s/.*\= *//p' ~/.npmrc`
fi

# ============================================================================
# DIRECTORY SHORTCUTS
# ============================================================================

export workspace=~/workspace
export infra=~/workspace/infra/
export mbox=$MOTHERBOX_ROOT # comes from .local.zshrc
export inbox=~/Documents/"000_Inbox"
export iCloud=~/iCloud
export icloud=~/iCloud  # Both cases for convenience - prevents typos
export nlp=~/workspace/infra/neat-little-package

# ============================================================================
# CUSTOM FUNCTIONS
# ============================================================================

# Automatically ls after cd
cd () {
  builtin cd "$@";
  ls -a;
}

# Slightly more user-friendly man pages
tldr () {
  if curl -s "cheat.sh/$1" 2>/dev/null; then
    # Success - curl worked
    :
  else
    echo "Failed to fetch cheat sheet for '$1', falling back to man page..."
    man "$1"
  fi
}

# ============================================================================
# PATH CONFIGURATION
# ============================================================================

# PATH modifications
export PATH="$PATH:$HOME/.config/motherbox/bin:$HOME/.local/bin"  # Personal scripts and tools
export PATH="$BREW_PREFIX/opt/bison/bin:$PATH"  # Modern bison for parser generation
export PATH="$PATH:$HOME/.lmstudio/bin" # Local Llama Studio binaries
export PATH="$PATH:$HOME/.antigravity/antigravity/bin" # Google's Antigravity - agry

# Remove duplicates from PATH
typeset -U PATH

# ============================================================================
# ALIASES & SHORTCUTS
# ============================================================================

# Shell convenience
alias rezsh="source ~/.zshrc"
alias zshcfg='code -nw "$(readlink ~/.zshrc 2>/dev/null || echo ~/.zshrc)"'

# Motherbox repo shortcut (derived from zshrc symlink location)
alias motherbox='cd "$(dirname "$(readlink ~/.zshrc)")"/../..'

# Enhanced & tool overwrites
command -v bat >/dev/null 2>&1 && alias cat='bat'
if command -v eza >/dev/null 2>&1; then
  alias ls='eza -a'
  alias tree='eza --tree'
else
  alias ls="ls -aG"  # Enhanced ls: show all files and use color (fallback)
fi

# Ruby aliases
alias be="bundle exec"
alias rake="noglob rake"

# Directory navigation shortcuts
alias pd='pushd'
alias pp='popd'
alias dirs='dirs -v'

# Say the magic word
alias please='sudo $(fc -ln -1)'

# Claude helpers
alias cld='claude'
alias cldup='curl -fsSL https://claude.ai/install.sh | bash'
alias clddanger='claude --allow-dangerously-skip-permissions'
alias cldc='claude --continue'
alias cldr='claude --resume'
alias cldp='claude --print'

# Doin things
alias c='clear'

# ============================================================================
# GIT SHORTHANDS
# ============================================================================
# Shorthand the stuff I most frequently use
alias gst='git status'
alias gaco='git aco'
alias gpub='git pub'
alias greup='git reup'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcob='git checkout -b'
alias gdff='git diff'
alias grbp='git rebase-and-push'

# ============================================================================
# Work laptop overrides
# ============================================================================
# Grab any galileo-specific aliases & configs
if [ -f ~/.galileorc ]; then
  source ~/.galileorc
fi

