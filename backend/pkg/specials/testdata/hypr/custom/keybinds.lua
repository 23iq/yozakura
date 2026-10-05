-- Local shortcuts complement the shell; shell bindings live in binds.json.
hl.bind("CTRL + SUPER + ALT + Slash", hl.dsp.exec_cmd("yozakura run config"), { description = "the shell: Keybinding settings" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize" })
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: Fullscreen" })
hl.bind("SUPER + P", hl.dsp.window.pin(), { description = "Window: Pin" })
hl.bind("SUPER + CTRL + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), { description = "Session: Sleep" })
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("Telegram"), { description = "Workspace: Telegram" })
hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:Telegram", follow = false }), { description = "Window: Send to Telegram" })
hl.bind("SUPER + D", hl.dsp.workspace.toggle_special("Discord"), { description = "Workspace: Discord" })
hl.bind("SUPER + ALT + D", hl.dsp.window.move({ workspace = "special:Discord", follow = false }), { description = "Window: Send to Discord" })
hl.bind("SUPER + C", hl.dsp.workspace.toggle_special("Dev"), { description = "Workspace: Dev" })
hl.bind("SUPER + ALT + C", hl.dsp.window.move({ workspace = "special:Dev", follow = false }), { description = "Window: Send to Dev" })

-- Native resize dispatches: the shell currently generates exec commands for resizeactive.
hl.bind("SUPER + ALT + j", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { description = "Window: Increase height" })
hl.bind("SUPER + ALT + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { description = "Window: Increase height" })
hl.bind("SUPER + ALT + k", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { description = "Window: Decrease height" })
hl.bind("SUPER + ALT + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { description = "Window: Decrease height" })

-- Ctrl+J/K collects/expels to the right; adding Shift selects the left side.
scrolling_actions = require("custom.scrolling")
hl.bind("SUPER + CTRL + j", function() scrolling_actions.collect("right") end, { description = "Scrolling: Collect from right" })
hl.bind("SUPER + CTRL + Down", function() scrolling_actions.collect("right") end, { description = "Scrolling: Collect from right" })
hl.bind("SUPER + CTRL + SHIFT + j", function() scrolling_actions.collect("left") end, { description = "Scrolling: Collect from left" })
hl.bind("SUPER + CTRL + SHIFT + Down", function() scrolling_actions.collect("left") end, { description = "Scrolling: Collect from left" })
hl.bind("SUPER + CTRL + k", function() scrolling_actions.expel("right") end, { description = "Scrolling: Expel to right" })
hl.bind("SUPER + CTRL + Up", function() scrolling_actions.expel("right") end, { description = "Scrolling: Expel to right" })
hl.bind("SUPER + CTRL + SHIFT + k", function() scrolling_actions.expel("left") end, { description = "Scrolling: Expel to left" })
hl.bind("SUPER + CTRL + SHIFT + Up", function() scrolling_actions.expel("left") end, { description = "Scrolling: Expel to left" })
