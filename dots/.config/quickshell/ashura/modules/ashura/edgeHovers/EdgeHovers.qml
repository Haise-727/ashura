import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ashura.mediaControls
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland

// Ashura edge hovers. Thin strips in the middle of three screen edges, each with a
// small highlight that grows while the pointer is on it (as in the old Ashura
// shell). No dragging: this touchpad cannot drag reliably.
//
//   right   hover -> volume and brightness sliders (caelestia-style); click the
//                    edge or the panel -> the full right sidebar.
//                    The same sliders pop up when volume or brightness changes
//                    (replaces the old on-screen display).
//   left    hover 1 s, or click -> the left sidebar (translator, booru).
//   bottom  hover -> the music card; it stays while the pointer is on it.
//
// The strips are on the Top layer, so fullscreen windows cover them.
// IPC: `qs -c ashura ipc call edgeHovers toggle` (all strips on/off).
Scope {
    id: root
    property bool enabled: true
    readonly property int depth: 3              // px of edge that reacts
    readonly property int dwellMs: 1000         // left edge: hover this long to open
    readonly property int graceMs: 300          // time to move from edge to panel

    // ---- right: sliders ----
    property bool rightEdgeHovered: false
    property bool slidersHovered: false
    readonly property bool slidersShown: !GlobalStates.sidebarRightOpen && !GlobalStates.screenLocked
        && (rightEdgeHovered || slidersHovered || rightGrace.running || osdTimer.running)

    // ---- bottom: music ----
    property bool bottomEdgeHovered: false
    property bool musicHovered: false
    readonly property bool musicShown: !GlobalStates.overviewOpen && !GlobalStates.screenLocked
        && (bottomEdgeHovered || musicHovered || bottomGrace.running)

    Timer { id: rightGrace; interval: root.graceMs }
    Timer { id: bottomGrace; interval: 150 }    // short: it closes almost at once
    onRightEdgeHoveredChanged: if (!rightEdgeHovered) rightGrace.restart()
    onSlidersHoveredChanged: if (!slidersHovered) rightGrace.restart()
    onBottomEdgeHoveredChanged: if (!bottomEdgeHovered) bottomGrace.restart()
    onMusicHoveredChanged: if (!musicHovered) bottomGrace.restart()

    // On-screen display: show the sliders for a moment when a value changes.
    // Not during the first seconds, while devices report their initial values.
    property bool osdArmed: false
    Timer { interval: 2500; running: true; onTriggered: root.osdArmed = true }
    Timer { id: osdTimer; interval: Config.options.osd.timeout + 500 }
    function osd() { if (root.osdArmed) osdTimer.restart(); }
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() { root.osd(); }
        function onMutedChanged() { root.osd(); }
    }
    Connections {
        target: Brightness.monitors[0] ?? null
        function onBrightnessChanged() { root.osd(); }
    }

    function openSidebar(side) {
        root.rightEdgeHovered = false;
        root.slidersHovered = false;
        osdTimer.stop();
        GlobalStates.sidebarLeftOpen = side === "left";
        GlobalStates.sidebarRightOpen = side === "right";
    }

    // The music card reads bars from the shared cava while it is up.

    // ------------------------------------------------------------ edge strip
    component Strip: PanelWindow {
        id: strip
        required property string side
        required property var screenRef
        property alias hovered: area.containsMouse
        signal clicked()
        screen: screenRef
        readonly property bool vertical: side === "left" || side === "right"
        anchors { left: side === "left"; right: side === "right"; bottom: side === "bottom" }
        implicitWidth: vertical ? root.depth : Math.round((screenRef?.width ?? 1920) * 0.30)
        implicitHeight: vertical ? Math.round((screenRef?.height ?? 1080) * 0.40) : root.depth
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: `quickshell:edgeHover:${side}`
        WlrLayershell.layer: WlrLayer.Top
        visible: root.enabled

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: strip.clicked()
        }
        // The highlight: a short line that grows and brightens on hover.
        Rectangle {
            anchors.centerIn: parent
            width: strip.vertical ? 3 : (area.containsMouse ? parent.width * 0.75 : parent.width * 0.3)
            height: strip.vertical ? (area.containsMouse ? parent.height * 0.75 : parent.height * 0.3) : 3
            radius: 2
            color: Appearance.colors.colPrimary
            opacity: area.containsMouse ? 0.9 : 0.0
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData

            // ---- right
            Strip {
                side: "right"; screenRef: perScreen.modelData
                onHoveredChanged: root.rightEdgeHovered = hovered
                onClicked: root.openSidebar("right")
            }
            PanelWindow {
                id: slidersWin
                screen: perScreen.modelData
                anchors.right: true
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "quickshell:edgeSliders"
                WlrLayershell.layer: WlrLayer.Overlay
                implicitWidth: slidersCard.implicitWidth
                implicitHeight: slidersCard.implicitHeight
                visible: root.slidersShown || slidersCard.slide < 1

                // Hover is checked on the whole window, flush with the screen
                // edge: a margin between the edge and the card made the panel
                // hide and reopen every second with the pointer on the edge.
                // A handler, not a MouseArea: the sliders take hover themselves.
                // The card is a CHILD of this item, so its HoverHandler still sees
                // the pointer while the sliders take hover for themselves (a
                // handler on a sibling lost it: the panel closed and reopened).
                Item {
                    id: slidersHoverRoot
                    anchors.fill: parent
                    HoverHandler { onHoveredChanged: root.slidersHovered = hovered }
                }

                // Attached to the edge (caelestia-style): rounded on the inside only.
                Rectangle {
                    id: slidersCard
                    parent: slidersHoverRoot
                    property real slide: root.slidersShown ? 0 : 1      // 0 = in, 1 = out
                    Behavior on slide { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    x: slide * (width + 2)
                    implicitWidth: slidersCol.implicitWidth + 20
                    implicitHeight: slidersCol.implicitHeight + 28
                    topLeftRadius: Appearance.rounding.large
                    bottomLeftRadius: Appearance.rounding.large
                    topRightRadius: 0
                    bottomRightRadius: 0
                    color: Appearance.colors.colLayer0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openSidebar("right")
                    }

                    ColumnLayout {
                        id: slidersCol
                        anchors.centerIn: parent
                        spacing: 10

                        FilledSlider {
                            Layout.alignment: Qt.AlignHCenter
                            icon: (Audio.sink?.audio.muted ?? false) ? "volume_off"
                                : value > 0.66 ? "volume_up" : value > 0 ? "volume_down" : "volume_mute"
                            from: 0
                            to: Audio.maxVolume
                            value: Audio.sink?.audio.volume ?? 0
                            onMoved: if (Audio.sink) Audio.sink.audio.volume = value
                        }
                        FilledSlider {
                            readonly property var monitor: Brightness.getMonitorForScreen(perScreen.modelData)
                            Layout.alignment: Qt.AlignHCenter
                            icon: "light_mode"
                            from: 0
                            to: 1
                            value: monitor?.brightness ?? 0
                            onMoved: monitor?.setBrightness(value)
                        }
                    }
                }
            }

            // ---- left
            Strip {
                id: leftStrip
                side: "left"; screenRef: perScreen.modelData
                onClicked: root.openSidebar("left")
                // Only a fresh arrival on the edge counts: closing the sidebar
                // with the pointer still there must not reopen it.
                onHoveredChanged: if (hovered && !GlobalStates.sidebarLeftOpen) dwell.restart(); else dwell.stop()
                Timer {
                    id: dwell
                    interval: root.dwellMs
                    onTriggered: if (leftStrip.hovered) root.openSidebar("left")
                }
            }

            // ---- bottom
            Strip {
                side: "bottom"; screenRef: perScreen.modelData
                onHoveredChanged: root.bottomEdgeHovered = hovered
            }
            // The music bar: hangs from the bottom edge, joined to it by
            // inverted corners (as the dashboard hangs from the bar). Always
            // mapped, empty and click-through while closed, so opening does not
            // stall on creating the window.
            PanelWindow {
                id: musicWin
                screen: perScreen.modelData
                anchors.bottom: true
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "quickshell:edgeMusic"
                WlrLayershell.layer: WlrLayer.Overlay
                readonly property real fillet: Appearance.rounding.screenRounding
                implicitWidth: musicBar.implicitWidth + fillet * 2
                implicitHeight: 116
                visible: true
                mask: Region { item: (root.musicShown || musicSlide.slide < 1) ? musicHoverRoot : noMusicInput }
                Item { id: noMusicInput; width: 0; height: 0 }

                Item {
                    id: musicHoverRoot
                    anchors.fill: parent
                    HoverHandler { onHoveredChanged: root.musicHovered = hovered }

                    Item {
                        id: musicSlide
                        property real slide: root.musicShown ? 0 : 1
                        Behavior on slide { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                        width: parent.width
                        height: parent.height
                        y: slide * (height + 2)

                        Rectangle {
                            id: barBg
                            x: musicWin.fillet
                            anchors.bottom: parent.bottom
                            width: musicBar.implicitWidth
                            height: musicBar.implicitHeight
                            color: Appearance.colors.colLayer0
                            topLeftRadius: Appearance.rounding.large
                            topRightRadius: Appearance.rounding.large
                            MusicBar { id: musicBar; anchors.fill: parent }
                        }
                        RoundCorner {
                            anchors { right: barBg.left; bottom: parent.bottom }
                            implicitSize: musicWin.fillet
                            color: Appearance.colors.colLayer0
                            corner: RoundCorner.CornerEnum.BottomRight
                        }
                        RoundCorner {
                            anchors { left: barBg.right; bottom: parent.bottom }
                            implicitSize: musicWin.fillet
                            color: Appearance.colors.colLayer0
                            corner: RoundCorner.CornerEnum.BottomLeft
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "edgeHovers"
        function toggle(): void { root.enabled = !root.enabled; }
        function osd(): void { root.osdArmed = true; root.osd(); }
    }
}
