export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR='code'

# Keep less from paginating unless it needs to.
export LESS="-FRXK"

# Hug the face.
export HF_HOME="$HOME/.cache/huggingface"

# OpenSCAD custom library path avoids cluttering ~/Documents.
export OPENSCADPATH="$HOME/OpenSCAD/Libraries"

# Local secrets live in ~/.config/zsh/env.local.zsh, which .zshenv sources
# before this file. Non-secret shared environment belongs in this managed zsh
# config.
export MOTHERBOX_ROOT="$HOME/dev/apps/motherbox"

# eza reads theme.yml from here; its macOS default is ~/Library/Application Support.
export EZA_CONFIG_DIR="$HOME/.config/eza"
