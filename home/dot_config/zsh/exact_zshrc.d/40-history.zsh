HISTSIZE=50000
HISTFILE="${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}/history"
SAVEHIST=50000
HISTDUP=erase # Erase duplicates in the history file.
setopt appendhistory # Append history to the history file without overwriting.
setopt sharehistory # Share history across terminals.
setopt incappendhistory # Immediately append to the history file.
setopt extendedhistory # Save timestamps in history file.
unsetopt nomatch # Do not error if there are no matches.
