if command -v direnv >/dev/null 2>&1; then
	eval "$(direnv hook zsh)"
fi

if command -v wt >/dev/null 2>&1; then
	eval "$(wt config shell init zsh)"
fi
