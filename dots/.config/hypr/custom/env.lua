-- Ashura: environment overrides, loaded after the base hyprland/env.lua.

-- Qt apps take the wallpaper palette through qt6ct (matugen writes
-- ~/.config/qt6ct/colors/ashura.conf). The base used "kde", which needs
-- plasma-integration and much of KDE Frameworks.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
