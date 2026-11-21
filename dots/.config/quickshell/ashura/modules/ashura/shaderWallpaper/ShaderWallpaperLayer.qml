import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Ashura: draws the shader live wallpaper behind everything, in the palette's
// colours. Bass from cava drives it while music plays, and the cursor lights it
// where it moves over the desktop (the surface receives hover only where no
// window is, like Wallpaper Engine). Clicks are not used.
Scope {
    id: root
    // Nothing to draw while every screen shows a fullscreen (or maximized)
    // window: the clock and the cava both stop, so the GPU rests.
    readonly property bool covered: Hyprland.monitors.values.length > 0
        && Hyprland.monitors.values.every(m => m.activeWorkspace?.hasFullscreen ?? false)
    readonly property bool animating: ShaderWallpaper.active && !root.covered
    readonly property real bass: root.animating ? CavaFeed.bass : 0
    property real time: 0

    Binding { target: CavaFeed; property: "wantShader"; value: root.animating }

    // 30 updates a second is plenty for slow light and keeps the GPU mostly idle.
    Timer {
        interval: 33
        repeat: true
        running: root.animating
        onTriggered: root.time += 0.033
    }

    Variants {
        model: ShaderWallpaper.active ? Quickshell.screens : []
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.namespace: "quickshell:shaderWallpaper"
            WlrLayershell.layer: WlrLayer.Background

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Quickshell.shellPath(`assets/ashura/shaders/${ShaderWallpaper.shader}.frag.qsb`)
                property real time: root.time
                property real bass: root.bass
                property real aspect: width / Math.max(1, height)
                property point mouse: hover.containsMouse ? Qt.point(hover.mouseX / width, hover.mouseY / height) : Qt.point(-1, -1)
                property color base: Appearance.m3colors.m3surface
                property color colA: Appearance.colors.colPrimary
                property color colB: Appearance.m3colors.m3tertiary
            }
        }
    }
}
