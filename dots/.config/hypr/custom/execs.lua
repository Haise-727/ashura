-- Ashura autostart, loaded after the base hyprland/execs.lua.

hl.on("hyprland.start", function ()
    -- Never strand the session behind a dead lock screen; see the script's header.
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/ashura-lockguard >> $HOME/.local/state/ashura/lockguard.log 2>&1")
end)
