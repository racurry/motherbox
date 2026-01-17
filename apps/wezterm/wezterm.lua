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


----- macOS SPECIFIC -----

-- Option as Alt (left=Alt, right=compose for special chars)
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = true


----- TABS -----

config.hide_tab_bar_if_only_one_tab = false


----- SCROLLBACK -----

config.scrollback_lines = 8000


----- THEME -----

config.color_scheme = 'Catppuccin Mocha'


return config
