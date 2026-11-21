import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.ashura.background
import qs.modules.ashura.bar
import qs.modules.ashura.cheatsheet
import qs.modules.ashura.lock
import qs.modules.ashura.mediaControls
import qs.modules.ashura.notificationPopup
import qs.modules.ashura.onScreenDisplay
import qs.modules.ashura.onScreenKeyboard
import qs.modules.ashura.overview
import qs.modules.ashura.polkit
import qs.modules.ashura.regionSelector
import qs.modules.ashura.screenCorners
import qs.modules.ashura.screenTranslator
import qs.modules.ashura.sessionScreen
import qs.modules.ashura.sidebarLeft
import qs.modules.ashura.sidebarRight
import qs.modules.ashura.wallpaperSelector
import qs.modules.ashura.loginTheme // Ashura
import qs.modules.ashura.startup // Ashura
import qs.modules.ashura.edgeVisualizer // Ashura
import qs.modules.ashura.lyrics // Ashura
import qs.modules.ashura.shaderWallpaper // Ashura
import qs.modules.ashura.edgeHovers // Ashura
import qs.modules.ashura.ashuraPicker // Ashura
import qs.modules.ashura.waveBorder // Ashura

Scope {
    PanelLoader { component: Bar {} }
    PanelLoader { component: Background {} }
    PanelLoader { component: ShaderWallpaperLayer {} } // shader live wallpaper, above the background
    PanelLoader { component: Cheatsheet {} }
    PanelLoader { component: Lock {} }
    PanelLoader { component: MediaControls {} }
    PanelLoader { component: NotificationPopup {} }
    // The on-screen display is the edge sliders (EdgeHovers).
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Overview {} }
    PanelLoader { component: Polkit {} }
    PanelLoader { component: RegionSelector {} }
    PanelLoader { component: ScreenCorners {} }
    PanelLoader { component: ScreenTranslator {} }
    PanelLoader { component: SessionScreen {} }
    PanelLoader { component: SidebarLeft {} }
    PanelLoader { component: SidebarRight {} }
    PanelLoader { component: WallpaperSelector {} }
    PanelLoader { component: WallpaperCarousel {} } // Ashura: coverflow picker (Super+Shift+W)
    PanelLoader { component: LoginThemePicker {} } // Ashura: login screen theme
    PanelLoader { component: StartupDashboard {} } // Ashura: startup workspace (ws10)
    PanelLoader { component: EdgeVisualizer {} } // Ashura: music along the bottom edge
    PanelLoader { component: LyricsWidget {} } // Ashura: synced lyrics on the desktop
    PanelLoader { component: WaveBorder {} } // Ashura: a sound wave round the focused window
    PanelLoader { component: EdgeHovers {} } // Ashura: hover the screen edges for sliders, sidebars, music
}
