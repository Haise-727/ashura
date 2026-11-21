-- Ashura: default apps. Loaded right after the base hyprland/variables.lua, so these
-- globals replace its "first available" picks (which would choose foot,
-- Chrome, Antigravity and Dolphin on this machine).
terminal = "kitty"
browser = "firefox"
codeEditor = "code"
-- nautilus, not dolphin: Haise measured both (2026-08-27); dolphin pulls in 67 KDE
-- packages and the baloo indexer, nautilus 24 and matches the GTK theming.
fileManager = "nautilus"

-- Every Super combo cancels the "tap Super = search" trigger (see the file).
require("custom.super_release")
