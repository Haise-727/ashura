

-- Ashura panels draw their own opaque backgrounds. With the blur the base gives
-- every quickshell layer, a panel that slides or fades in crosses the blur
-- cut-off (ignore_alpha) mid-animation and the blurred backdrop flashes.
for _, ns in ipairs({ "quickshell:dashboard.*", "quickshell:mixerPanel.*", "quickshell:edgeSliders",
    "quickshell:edgeMusic", "quickshell:edgeHover:.*", "quickshell:desktopClock", "quickshell:wallpaperFx", "quickshell:waveBorder" }) do
    hl.layer_rule({ match = { namespace = ns }, blur = false })
    hl.layer_rule({ match = { namespace = ns }, no_anim = true })   -- they animate themselves
end
