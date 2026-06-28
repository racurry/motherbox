# Automatically ls after cd.
cd () {
  builtin cd "$@";
  ls -a;
}

# Slightly more user-friendly man pages.
tldr () {
  if curl -s "cheat.sh/$1" 2>/dev/null; then
    :
  else
    echo "Failed to fetch cheat sheet for '$1', falling back to man page..."
    man "$1"
  fi
}
