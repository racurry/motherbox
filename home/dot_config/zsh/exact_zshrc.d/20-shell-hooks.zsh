if command -v wt >/dev/null 2>&1; then
	eval "$(wt config shell init zsh)"
	# In Herdr, the post-switch hook opens worktrees as nested spaces; keep
	# this pane where it is. `wt switch --cd` overrides.
	[[ "${HERDR_ENV:-}" == 1 ]] && export WORKTRUNK_SWITCH__CD=false
fi

if command -v atuin >/dev/null 2>&1; then
	eval "$(atuin init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
	eval "$(direnv hook zsh)"
fi
