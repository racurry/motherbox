# The native installer puts Atuin and its PATH setup under ~/.atuin/bin.
if [ -r "$HOME/.atuin/bin/env" ]; then
	source "$HOME/.atuin/bin/env"
fi
