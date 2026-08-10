# Homebrew setup
# Ensure Homebrew is on the path.
eval "$(/opt/homebrew/bin/brew shellenv)"

# Set Homebrew prefix for reuse throughout shell and exported for subprocesses.
export BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"

# Activate mise.
eval "$(mise activate zsh)"

# Activate Cargo
. "$HOME/.cargo/env"
