# Personal scripts and tools.
export PATH="$PATH:$HOME/.config/motherbox/bin:$HOME/.local/bin"

# Modern bison for parser generation.
export PATH="$BREW_PREFIX/opt/bison/bin:$PATH"

# Google's Antigravity - agry.
export PATH="$PATH:$HOME/.antigravity/antigravity/bin"

export PATH="$HOME/.opencode/bin:$PATH"

# Remove duplicates from PATH.
typeset -U PATH
