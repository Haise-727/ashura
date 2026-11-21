import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Ashura: synced lyrics on the desktop, like SekaiPop's lyrics widget. Sits above
// the wallpaper and below windows, low in the middle of the screen, showing the
// line before, the current line (large, in the accent) and the next one. Only
// while something plays and LRCLIB has synced lyrics for it.
// Toggle: `qs -c ashura ipc call lyrics toggle`.
Scope {
    id: root
    property bool enabled: true
    readonly property bool show: root.enabled && Lyrics.playing && Lyrics.status === "found" && Lyrics.current.length > 0

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { left: true; right: true; bottom: true }
            margins.bottom: 70                      // clear of the edge visualizer
            implicitHeight: column.implicitHeight + 20
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:lyrics"
            WlrLayershell.layer: WlrLayer.Bottom
            mask: Region {}
            visible: column.opacity > 0

            ColumnLayout {
                id: column
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: 4
                opacity: root.show ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 400 } }
                layer.enabled: true
                layer.effect: DropShadow {
                    radius: 12
                    samples: 25
                    color: Qt.rgba(0, 0, 0, 0.75)
                    verticalOffset: 1
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Lyrics.previous
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: Qt.rgba(1, 1, 1, 0.55)
                }
                StyledText {
                    id: currentLine
                    Layout.alignment: Qt.AlignHCenter
                    text: Lyrics.current
                    font.family: Appearance.font.family.expressive
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colPrimary
                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation { target: currentLine; property: "opacity"; to: 0.2; duration: 90 }
                            PropertyAction {}
                            NumberAnimation { target: currentLine; property: "opacity"; to: 1; duration: 160 }
                        }
                    }
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Lyrics.next
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: Qt.rgba(1, 1, 1, 0.55)
                }
            }
        }
    }

    IpcHandler {
        target: "lyrics"
        function toggle(): void { root.enabled = !root.enabled; }
    }
}
