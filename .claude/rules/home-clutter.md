---
paths:
  - "home/**"
---

# What `$HOME` clutter matters

- Shell startup files in `$HOME` (`.zshrc`, `.zprofile`, `.profile`, ...) are the real concern. They change shell behavior behind chezmoi's back. Keep them out with `.chezmoiremove`, and fold anything useful they contain into `home/dot_config/zsh/`.
- Third-party dotdirs from tools that ignore XDG (e.g. `~/.zsh/`, `~/.snowflake/`) are tolerated. Use a tool's default location instead of building caches, regeneration, or relocation logic to move its files out of `$HOME`.
- Never delete anything in `$HOME` without User approval.
