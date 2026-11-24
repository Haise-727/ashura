-- Ashura keybinds, loaded after the base binds in hyprland/keybinds.lua.
--
-- Three jobs:
--   1. Haise's habits on top of the base layout.
--   2. Every base bind that needs ALT gets an Alt-free key. This keyboard has no
--      working Alt (Left Alt is dead; Right Alt is Super, see custom/general.lua).
--      The ALT originals are unbound, so the cheatsheet only lists keys that exist.
--   3. Binds for features Ashura does not have are removed.
--
-- The cheatsheet groups binds by the text before ":" in `description`.

local qsIpc = "qs -c $qsConfig ipc call"
local qsIsAlive = qsIpc .. " TEST_ALIVE"
local qsScripts = "$HOME/.config/quickshell/$qsConfig/scripts"
local global = hl.dsp.global

local function unbind(...)
    for _, keys in ipairs({ ... }) do hl.unbind(keys) end
end

----------------------------------------------------------------------- habits
-- Tap Super = search and overview (base bind). Super+Space is the cockpit
-- picker: the '@' key does not work on this keyboard, so typing '@' in search
-- is not an option.
hl.bind("SUPER + Space", global("quickshell:cockpitPicker"), { description = "Cockpit: Pick a repo" })

-- Q drops out on this keyboard, so closing has a key off the faulty matrix line.
hl.bind("SUPER + BackSpace", hl.dsp.window.close(), { description = "Window: Close" })

-- Super+W is a random wallpaper (and palette), as it was in the first Ashura.
-- The base had the browser there; it moves to Super+R.
unbind("SUPER + W", "CTRL + SUPER + ALT + T")
hl.bind("SUPER + W", global("quickshell:ashuraWallpaperRandom"), { description = "Appearance: Random wallpaper" })
hl.bind("SUPER + R", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
-- The coverflow picker on Super+Shift+W, next to the random one. The grid
-- picker stays on Ctrl+Super+T (it can browse any folder).
hl.bind("SUPER + SHIFT + W", global("quickshell:ashuraWallpaperPicker"), { description = "Appearance: Pick a wallpaper" })

-- Volume in steps of 5 (the base uses 2), up to 200%.
unbind("XF86AudioRaiseVolume", "XF86AudioLowerVolume")
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 2.0"),
    { locked = true, repeating = true, description = "Media: Volume up 5% (to 200%)" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true, description = "Media: Volume down 5%" })

-- No scratchpad (the base's special workspace on Super+S). Haise's "special"
-- workspace is ws 10, the launch dashboard.
unbind("SUPER + S", "CTRL + SUPER + S", "SUPER + mouse:275")
-- Super+S is the screenshot tool (Super+Shift+S still works too).
hl.bind("SUPER + S", hl.dsp.global("quickshell:regionScreenshot"), { description = "Utilities: Screenshot" })

-- Super+D is the cockpit (custom/cockpit.lua). Maximize moves to
-- Super+Shift+D.
local cockpit = require("custom.cockpit")
unbind("SUPER + D")
hl.bind("SUPER + D", function() cockpit.toggle() end, { description = "Cockpit: Show/hide" })
hl.bind("CTRL + SUPER + D", function() if cockpit.current then cockpit.close(cockpit.current) end end,
    { description = "Cockpit: Close this repo fully" })
hl.bind("CTRL + SUPER + SHIFT + D", function() cockpit.send_other() end,
    { description = "Cockpit: Send window to the other space (3 <-> 103)" })
hl.bind("SUPER + SHIFT + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
    { description = "Window: Maximize" })

------------------------------------------------------- stay inside the group
-- The base "workspace left/right" binds step plain ids ("r+1", "+1"), which walk
-- out of the cockpit (101-110) into user space. These step within the group.
for _, k in ipairs({ "CTRL + SUPER + Left", "SUPER + Page_Up", "CTRL + SUPER + Page_Up",
    "SUPER + mouse_up", "CTRL + SUPER + mouse_up", "CTRL + SUPER + BracketLeft" }) do
    unbind(k)
    hl.bind(k, function() ashura_group_step(-1) end,
        k == "CTRL + SUPER + Left" and { description = "Workspace: Focus left (stays in this group)" } or nil)
end
for _, k in ipairs({ "CTRL + SUPER + Right", "SUPER + Page_Down", "CTRL + SUPER + Page_Down",
    "SUPER + mouse_down", "CTRL + SUPER + mouse_down", "CTRL + SUPER + BracketRight" }) do
    unbind(k)
    hl.bind(k, function() ashura_group_step(1) end,
        k == "CTRL + SUPER + Right" and { description = "Workspace: Focus right (stays in this group)" } or nil)
end
unbind("CTRL + SUPER + Up", "CTRL + SUPER + Down")       -- jumped 5 ids
for _, k in ipairs({ "SUPER + SHIFT + Page_Up", "CTRL + SUPER + SHIFT + Left" }) do
    unbind(k)
    hl.bind(k, function() ashura_group_send(-1) end,
        k == "SUPER + SHIFT + Page_Up" and { description = "Window: Send to workspace left" } or nil)
end
for _, k in ipairs({ "SUPER + SHIFT + Page_Down", "CTRL + SUPER + SHIFT + Right" }) do
    unbind(k)
    hl.bind(k, function() ashura_group_send(1) end,
        k == "SUPER + SHIFT + Page_Down" and { description = "Window: Send to workspace right" } or nil)
end

--------------------------------------------------------------- Alt-free twins
-- Session menu (was Ctrl+Alt+Delete). The second bind is the fallback for when
-- the shell is not running.
unbind("CTRL + ALT + Delete")
hl.bind("SUPER + Escape", global("quickshell:sessionToggle"), { description = "Shell: Toggle session menu" })
hl.bind("SUPER + Escape", hl.dsp.exec_cmd(qsIsAlive .. " || pkill wlogout || wlogout -p layer-shell"))

-- Detached left sidebar (was Super+Alt+A).
unbind("SUPER + ALT + A")
hl.bind("CTRL + SUPER + A", global("quickshell:sidebarLeftToggleDetach"), { description = "Shell: Detach left sidebar" })

-- Screen recording. Region recording stays on Super+Shift+R (base bind); its
-- Alt duplicate goes. Fullscreen recording (was Ctrl+Alt+R) moves to
-- Ctrl+Super+Shift+R; with sound (was Super+Shift+Alt+R) on Ctrl+Super+Shift+V.
unbind("SUPER + ALT + R", "CTRL + ALT + R", "SUPER + SHIFT + ALT + R")
hl.bind("CTRL + SUPER + SHIFT + R", hl.dsp.exec_cmd(qsScripts .. "/videos/record.sh --fullscreen"),
    { locked = true, description = "Utilities: Record fullscreen" })

hl.bind("CTRL + SUPER + SHIFT + V", hl.dsp.exec_cmd(qsScripts .. "/videos/record.sh --fullscreen --sound"),
    { locked = true, description = "Utilities: Record fullscreen with sound" })

-- Media on the mouse side buttons (was Super+Shift+Alt+side buttons).
unbind("SUPER + SHIFT + ALT + mouse:275", "SUPER + SHIFT + ALT + mouse:276")
hl.bind("SUPER + SHIFT + mouse:275", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("SUPER + SHIFT + mouse:276", hl.dsp.exec_cmd("playerctl next"))

-- Microphone mute (was Super+Alt+M and Alt+Mute). XF86AudioMicMute still works.
unbind("SUPER + ALT + M", "ALT + XF86AudioMute")
hl.bind("CTRL + SUPER + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"),
    { locked = true, description = "Media: Toggle microphone" })

-- Window management.
unbind("ALT + F4", "SUPER + SHIFT + ALT + Q", "SUPER + ALT + Space", "SUPER + ALT + F")
hl.bind("SUPER + SHIFT + BackSpace", hl.dsp.exec_cmd("hyprctl kill"), { description = "Window: Forcefully zap a window" })
hl.bind("CTRL + SUPER + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })
hl.bind("CTRL + SUPER + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }),
    { description = "Window: Fake fullscreen" })

-- Send a window to workspace N without following it (was Super+Alt+N). The base has
-- no Super+Shift+number, so that is where it goes.
for i = 1, 10 do
    unbind("SUPER + ALT + " .. (i % 10))
    hl.bind("SUPER + SHIFT + " .. (i % 10), function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
    end, { description = "Window: Send to workspace " .. i })
end
for _, code in ipairs({ 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }) do
    unbind("SUPER + ALT + code:" .. code)
end
-- Alt duplicates of moves that already have Shift versions in the base.
unbind("SUPER + ALT + mouse_up", "SUPER + ALT + mouse_down", "SUPER + ALT + Page_up", "SUPER + ALT + Page_down",
    "CTRL + SUPER + ALT + Left", "CTRL + SUPER + ALT + Right")

-- Scratchpad send (was Super+Alt+S): gone with the scratchpad itself.
unbind("SUPER + ALT + S")

-- Apps that had Alt chords.
unbind("CTRL + SUPER + SHIFT + ALT + W", "CTRL + ALT + T")
hl.bind("CTRL + SUPER + SHIFT + W", hl.dsp.exec_cmd(officeSoftware), { description = "App: Office software" })

-- Rarely used chords with no replacement: test notifications and the
-- four-modifier power off (the session menu has it).
unbind("SUPER + ALT + F11", "SUPER + ALT + F12", "SUPER + ALT + Equal",
    "CTRL + SHIFT + ALT + SUPER + Delete", "CTRL + SUPER + ALT + Slash")

-- Virtual-machine passthrough mode (disables every bind so a VM gets the keys).
-- The base toggles it with Super+Alt+F1 from inside the submap; same logic here on
-- Ctrl+Super+F1, declared universal so it also works to get back out.
hl.define_submap("virtual-machine", function()
    hl.bind("CTRL + SUPER + F1", function()
        if hl.get_current_submap() == "virtual-machine" then
            hl.dispatch(hl.dsp.exec_cmd("notify-send 'Exited Virtual Machine submap' 'Keybinds re-enabled' -a 'Hyprland'"))
            hl.dispatch(hl.dsp.submap("reset"))
        else
            hl.dispatch(hl.dsp.exec_cmd("notify-send 'Entered Virtual Machine submap' 'Keybinds disabled. Hit Ctrl+Super+F1 to escape' -a 'Hyprland'"))
            hl.dispatch(hl.dsp.submap("virtual-machine"))
        end
    end, { submap_universal = true, description = "Session: Toggle VM passthrough" })
end)

------------------------------------------------------------------------ no AI
unbind("SUPER + SHIFT + ALT + mouse:273")

-- The base bind for editing this file used Alt; same action, Alt-free.
hl.bind("CTRL + SUPER + SHIFT + Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"),
    { description = "Shell: Edit user keybinds" })
