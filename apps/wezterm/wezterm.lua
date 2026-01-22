-- WezTerm Terminal Configuration
-- https://wezterm.org/config/lua/config/index.html

local wezterm = require 'wezterm'
local config = wezterm.config_builder()


----- FONTS -----

config.font = wezterm.font 'FiraCode Nerd Font Mono'
config.font_size = 17


----- WINDOW -----

config.window_background_opacity = 0.95
config.window_decorations = 'RESIZE' -- hides title bar
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }
config.window_close_confirmation = 'NeverPrompt'
config.skip_close_confirmation_for_processes_named = {
  'bash', 'sh', 'zsh', 'fish', 'tmux', 'nu', 'cmd.exe', 'pwsh.exe', 'powershell.exe',
}
config.default_cwd = wezterm.home_dir .. '/workspace'


----- macOS SPECIFIC -----

-- Option as Alt (left=Alt, right=compose for special chars)
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = true


----- TABS -----

config.hide_tab_bar_if_only_one_tab = false


----- KEY BINDINGS -----

local act = wezterm.action
config.keys = {
  { key = 'w', mods = 'CMD', action = act.CloseCurrentTab { confirm = false } },
  { key = 'w', mods = 'CMD|SHIFT', action = act.CloseCurrentPane { confirm = false } },
}


----- SCROLLBACK -----

config.scrollback_lines = 8000


----- THEME -----

config.color_scheme = 'Catppuccin Mocha'


return config
