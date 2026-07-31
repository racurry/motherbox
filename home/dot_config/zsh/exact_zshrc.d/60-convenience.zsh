# Directory shortcuts, as zsh named directories
hash -d code=~/code
hash -d me=~/code/me
hash -d mbox=$MOTHERBOX_ROOT
hash -d inbox=~/Documents/000_Inbox
hash -d icloud=~/iCloud
hash -d iCloud=~/iCloud # Both cases for convenience.
hash -d nlp=~/code/me/neat-little-package
hash -d memex=~/Notes/Memex

# Shell convenience.
rezsh() {
	source "${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}/.zshrc"
}

motherbox() {
	cd "$MOTHERBOX_ROOT"
}

# Enhanced tool defaults.
command -v bat >/dev/null 2>&1 && alias cat='bat'
if command -v eza >/dev/null 2>&1; then
	alias ls='eza -a'
	alias tree='eza --tree'
else
	alias ls='ls -aG'
fi

cd() {
	builtin cd "$@" || return
	ls
}

# Slightly more user-friendly man pages.
tldr() {
	if curl -s "cheat.sh/$1" 2>/dev/null; then
		:
	else
		echo "Failed to fetch cheat sheet for '$1', falling back to man page..."
		man "$1"
	fi
}

# Re-run the previous command with sudo.
please() {
	local last_command

	fc -ln -1 | read -r last_command
	if [ -z "$last_command" ]; then
		return 1
	fi

	print -s "sudo $last_command"
	sudo zsh -c "$last_command"
}

# Ruby aliases.
alias be='bundle exec'
alias rake='noglob rake'

# Directory navigation shortcuts.
alias pd='pushd'
alias pp='popd'
alias dirs='dirs -v'

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
alias cz='chezmoi'
alias czst='chezmoi status'
alias czap='chezmoi apply'
