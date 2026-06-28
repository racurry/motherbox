# Homebrew setup
# Ensure Homebrew is on the path.
eval "$(/opt/homebrew/bin/brew shellenv)"

# Set Homebrew prefix for reuse throughout shell and exported for subprocesses.
export BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"

# Only auto-update Homebrew once per day (86400 seconds).
export HOMEBREW_AUTO_UPDATE_SECS=86400
export HOMEBREW_NO_ENV_HINTS=1

# Activate mise.
eval "$(mise activate zsh)"
