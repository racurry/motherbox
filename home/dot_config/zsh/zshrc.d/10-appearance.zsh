# Use the pure prompt.
autoload -U promptinit; promptinit
prompt pure

# Set terminal title to current directory using ~ for home.
precmd() { print -Pn "\e]2;%~\a" }
