# Print the cached drift check. A missing cache means it has never run here,
# which is not the same claim as a clean one.
() {
	local cache=${XDG_CACHE_HOME:-$HOME/.cache}/motherbox/status
	if [[ ! -e $cache ]]; then
		print -r -- 'motherbox: never checked — motherbox-status'
		return 0
	fi
	[[ -s $cache ]] || return 0
	print -r -- "$(<$cache)"
}
