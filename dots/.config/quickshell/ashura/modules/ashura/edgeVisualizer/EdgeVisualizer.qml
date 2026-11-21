import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Ashura: a music visualizer along the bottom edge of the screen, in place of a
// cava strip in the bar. Thin bars in the palette's accent, mirrored from the
// centre, fading in only while something plays. The surface takes no input
// (empty mask), so clicks go to whatever is underneath. Bars come from the
// shared CavaFeed.
// Toggle: `qs -c ashura ipc call edgeVisualizer toggle`.
Scope {
    id: root
    property bool enabled: AshuraSettings.edgeVisualizer   // Settings, Music
    readonly property bool playing: MprisController.activePlayer?.isPlaying ?? false
    readonly property bool active: root.enabled && root.playing
    readonly property list<real> points: CavaFeed.points
    readonly property int maxHeight: 46

    Binding { target: CavaFeed; property: "wantEdge"; value: root.enabled }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: visWin
            required property var modelData
            screen: modelData
            // Windows on this screen's workspace that reach down into the strip:
            // where a bar stands over one of them it takes another colour, so it
            // reads over both the wallpaper and the window.
            readonly property int wsId: (HyprlandData.monitors.find(m => m.name === modelData.name)?.activeWorkspace?.id) ?? -1
            // With two or more windows the wave border takes over (Settings, Music).
            readonly property bool crowded: AshuraSettings.edgeVisualizerHideWithWindows
                && HyprlandData.windowList.filter(w => w.workspace?.id === visWin.wsId && !w.hidden).length > 1
            readonly property var winRects: HyprlandData.windowList
                .filter(w => w.workspace?.id === visWin.wsId && !w.hidden && (w.at[1] + w.size[1]) > (modelData.height - root.maxHeight))
                .map(w => [w.at[0] - (modelData.x ?? 0), w.at[0] - (modelData.x ?? 0) + w.size[0]])
            function overWindow(x) { return winRects.some(r => x >= r[0] && x <= r[1]); }
            anchors { left: true; right: true; bottom: true }
            implicitHeight: root.maxHeight
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:edgeVisualizer"
            WlrLayershell.layer: WlrLayer.Top
            mask: Region {}                 // never takes input
            visible: barRow.opacity > 0

            Row {
                id: barRow
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: root.maxHeight
                spacing: 3
                opacity: (root.active && !visWin.crowded) ? 0.85 : 0
                Behavior on opacity { NumberAnimation { duration: 600 } }

                // Mirror: right half is the points, left half the same reversed,
                // so the bass sits in the middle of the screen.
                readonly property var mirrored: root.points.slice().reverse().concat(root.points)
                // Ashura: the full width of the screen; bass in the middle, the ends
                // tapering down onto the bottom edge.
                readonly property real barWidth: Math.max(2, parent.width / Math.max(1, mirrored.length) - spacing)

                Repeater {
                    model: barRow.mirrored.length
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: barRow.barWidth
                        // cava's raw config outputs 0..1000
                        readonly property real taper: Math.pow(Math.sin(Math.PI * (index + 0.5) / barRow.mirrored.length), 0.7)
                        height: Math.max(2, Math.min(1, (barRow.mirrored[index] ?? 0) / CavaFeed.peak) * root.maxHeight * taper)   // scaled to the music's own peak
                        // round on top, square at the bottom: they stand flat on the edge
                        topLeftRadius: width / 2
                        topRightRadius: width / 2
                        readonly property bool overWin: visWin.overWindow(barRow.x + x + width / 2)
                        color: overWin ? Qt.lighter(Appearance.colors.colPrimary, 1.5)   // a light tint of the wallpaper's colour over windows
                                       : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.15)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "edgeVisualizer"
        function toggle(): void { root.enabled = !root.enabled; }
    }
}
