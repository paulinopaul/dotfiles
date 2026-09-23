hl.config({
    input = {
        kb_layout = "latam",
    },
})

hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@144",
    position = "0x0",
    scale = 1,
})

-- Keybinds for resizing active windows (width and height simultaneously)
local fn = require("utils.functions")
local repeating = { repeating = true }

hl.bind("SUPER + minus", fn.resize_active_window(-10, -10), repeating)
hl.bind("SUPER + plus", fn.resize_active_window(10, 10), repeating)
hl.bind("SUPER + KP_Subtract", fn.resize_active_window(-10, -10), repeating)
hl.bind("SUPER + KP_Add", fn.resize_active_window(10, 10), repeating)


hl.bind("SUPER + SPACE", hl.dsp.global("caelestia:wallpaperSelector"))
