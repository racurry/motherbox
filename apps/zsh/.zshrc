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

# Only auto-update Homebrew once per day (86400 seconds)
export HOMEBREW_AUTO_UPDATE_SECS=86400
export HOMEBREW_NO_ENV_HINTS=1


# ============================================================================
# SHELL APPEARANCE & BEHAVIOR
# ============================================================================

# Use the pure prompt
autoload -U promptinit; promptinit
prompt pure

autoload -Uz compinit && compinit
# Add asdf completions
fpath=(${ASDF_DIR}/completions $fpath)

# Source Homebrew-installed zsh plugins
source_brew_plugin() {
  [ -f "$BREW_PREFIX/$1" ] && source "$BREW_PREFIX/$1"
}

source_brew_plugin  "share/fzf-tab/fzf-tab.zsh"
source_brew_plugin "opt/fzf/shell/key-bindings.zsh"
source_brew_plugin "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"  

unset -f source_brew_plugin

# Set terminal title to current directory (using ~ for home)
precmd() { print -Pn "\e]2;%~\a" }

# ============================================================================
# Initialize a few things

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
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

# Local secrets and machine-specific env vars live in ~/.zshenv,
# which zsh loads automatically before this file (no source needed).

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================

HISTSIZE=50000
HISTFILE=~/.zsh_history
SAVEHIST=50000
HISTDUP=erase # Erase duplicates in the history file
setopt appendhistory # Append history to the history file (no overwriting)
setopt sharehistory # Share history across terminals
setopt incappendhistory # Immediately append to the history file, not just when a term is killed
setopt extendedhistory # Save timestamps in history file
unsetopt nomatch # Don't throw an error if there are no matches, just do the right thing

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

export code=~/code
export workspace=~/workspace
export infra=~/workspace/infra/
export mbox=$MOTHERBOX_ROOT # comes from ~/.zshenv
export inbox=~/Documents/"000_Inbox"
export iCloud=~/iCloud
export icloud=~/iCloud  # Both cases for convenience - prevents typos
export nlp=~/code/me/neat-little-package
export memex=~/Notes/Memex
export agents=~/ai_plaground

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
export PATH="$PATH:$HOME/.config/motherbox/scripts:$HOME/.local/bin"  # Personal scripts and tools
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
## - move to cc
alias cc='claude'
alias ccup='curl -fsSL https://claude.ai/install.sh | bash'
alias ccdanger='claude --allow-dangerously-skip-permissions'
alias ccc='claude --continue'
alias ccr='claude --resume'
alias ccp='claude --print'

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
# Grab any work-specific aliases & configs
if [ -f ~/.galileorc ]; then
  source ~/.galileorc
fi

if [ -f ~/.firsthandrc ]; then
  source ~/.firsthandrc
fi

# # Enable completion system (compinit must come before fzf-tab)

# [ -f "$BREW_PREFIX/share/fzf-tab/fzf-tab.zsh" ] && source "$BREW_PREFIX/share/fzf-tab/fzf-tab.zsh"
