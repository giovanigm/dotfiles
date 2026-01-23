-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

local mux = wezterm.mux

wezterm.on("gui-startup", function(cmd)
	local _, _, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)
-- This is where you actually apply your config choices

config.color_scheme = "Github Dark (Gogh)"

config.font_size = 16

-- config.window_background_opacity = 0.9

-- and finally, return the configuration to wezterm
return config
