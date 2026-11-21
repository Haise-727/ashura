-- Ashura: general overrides, loaded after the base hyprland/general.lua.

hl.config({
    input = {
        -- Right Alt acts as Super (Mod4). Left Alt is physically dead on this
        -- keyboard, so this leaves NO Alt key at all; custom/keybinds.lua gives
        -- every Alt bind an Alt-free twin. Super binds match the Mod4 bit,
        -- so they all answer to Right Alt with no further changes.
        kb_options = "altwin:swap_ralt_rwin",
    },
})

-- A border wide enough for the music pulse (services/BorderPulse) to show.
-- (The base uses 1 px.)
hl.config({ general = { border_size = 3 } })
