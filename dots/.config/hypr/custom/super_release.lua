-- Ashura: tapping Super alone toggles search (the shell's searchToggleRelease, fired
-- when Super is released). Quickshell sees that release even when Super was
-- held for a combo like Super+W, so after the combo search popped up too.
-- The shell cancels it with the global `searchToggleReleaseInterrupt`, which nothing
-- in this config sent. So every Super key bind made from here on gets a twin
-- bind on the same keys that sends that interrupt.
-- Left alone: binds on the Super keys themselves, release binds and mouse
-- drag binds. (Super+drag then release can still open search.)
if _G.__ashura_super_release then return end
_G.__ashura_super_release = true

local interrupt = hl.dsp.global("quickshell:searchToggleReleaseInterrupt")
local orig_bind = hl.bind

hl.bind = function(keys, action, opts)
    local result = orig_bind(keys, action, opts)
    local k = tostring(keys):upper()
    if k:find("SUPER", 1, true)
        and not k:find("SUPER_L", 1, true) and not k:find("SUPER_R", 1, true)
        and not (opts and (opts.mouse or opts.release)) then
        -- A second bind on the same keys, not a wrapper around the first:
        -- dispatching the global from inside a Lua bind made Hyprland run the
        -- bind twice (Super+D toggled the cockpit in and straight back out).
        orig_bind(keys, interrupt, { submap_universal = opts and opts.submap_universal or nil })
    end
    return result
end
