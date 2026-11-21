import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// The dashboard's Apps tab (panel style A4): every app with a window, heaviest
// first, as a bar as long as its share of memory, with the app's icon and name
// on the bar, its memory at the end and its CPU as a number with five dots.
// Hovering a row shows Close (asks the app nicely, so unsaved work can still
// prompt) and Force kill (SIGKILL). Memory and CPU cover the whole process tree.
Item {
    id: root
    Component.onCompleted: AppUsage.wanted = true
    Component.onDestruction: AppUsage.wanted = false

    readonly property real maxMem: Math.max(1, ...AppUsage.apps.map(a => a.memMb))

    function memText(mb) { return mb >= 1024 ? `${(mb / 1024).toFixed(1)} GB` : `${Math.round(mb)} MB`; }

    StyledText {
        anchors.centerIn: parent
        visible: AppUsage.apps.length === 0
        text: Translation.tr("No apps with windows")
        color: Appearance.colors.colSubtext
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 6
        model: AppUsage.apps
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: 40
            // Hovered while the pointer is on the row or on one of its buttons
            // (a button takes the hover from the row's own area).
            readonly property bool hot: rowHover.containsMouse || closeBtn.hovered || killBtn.hovered
            readonly property string iconSrc: {
                const p = Quickshell.iconPath(AppSearch.guessIcon(modelData.name), true);
                return p ? p : "";
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            // Track for the whole width, the bar for this app's memory.
            Rectangle {
                id: track
                anchors { left: parent.left; right: cpuBox.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                height: 32
                radius: 16
                color: "transparent"
                Rectangle {
                    id: bar
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Math.max(height * 3.2, (parent.width - memLabel.implicitWidth - 14) * row.modelData.memMb / root.maxMem)
                    radius: 16
                    color: row.hot ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    // The app's own icon; a lettered circle when it has none.
                    Item {
                        id: iconBox
                        x: 6; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22
                        IconImage {
                            anchors.fill: parent
                            visible: row.iconSrc !== ""
                            source: row.iconSrc
                            implicitSize: 22
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: row.iconSrc === ""
                            radius: 11
                            color: Appearance.colors.colLayer0
                            StyledText {
                                anchors.centerIn: parent
                                text: (row.modelData.name || "?").charAt(0).toUpperCase()
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer0
                            }
                        }
                    }
                    StyledText {
                        anchors { left: iconBox.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        text: row.modelData.name
                        font.weight: Font.Medium
                        color: row.hot ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                    }
                }
                StyledText {
                    id: memLabel
                    anchors { left: bar.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: root.memText(row.modelData.memMb)
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }
            }

            // CPU: the number and five dots; on hover, the two actions slide over it.
            Item {
                id: cpuBox
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 118
                height: parent.height

                RowLayout {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    opacity: row.hot ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    StyledText {
                        Layout.preferredWidth: 38
                        horizontalAlignment: Text.AlignRight
                        text: `${Math.round(row.modelData.cpu)}%`
                        font.family: Appearance.font.family.numbers
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }
                    Row {
                        spacing: 3
                        Repeater {
                            model: 5
                            delegate: Rectangle {
                                required property int index
                                width: 6; height: 6; radius: 3
                                // Each dot is a fifth of one core's worth (20% per dot).
                                color: index < Math.round(Math.min(100, row.modelData.cpu) / 20) ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                            }
                        }
                    }
                }
                RowLayout {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    opacity: row.hot ? 1 : 0
                    visible: opacity > 0
                    x: row.hot ? 0 : 12
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    RippleButton {
                        id: closeBtn
                        implicitWidth: 56; implicitHeight: 28
                        buttonRadius: 14
                        colBackground: Appearance.colors.colLayer2
                        onClicked: AppUsage.closeApp(row.modelData.pid)
                        contentItem: StyledText { anchors.centerIn: parent; text: Translation.tr("Close"); font.pixelSize: Appearance.font.pixelSize.smaller }
                    }
                    RippleButton {
                        id: killBtn
                        implicitWidth: 56; implicitHeight: 28
                        buttonRadius: 14
                        colBackground: Appearance.colors.colErrorContainer
                        onClicked: AppUsage.killApp(row.modelData.pid)
                        contentItem: StyledText { anchors.centerIn: parent; text: Translation.tr("Kill"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnErrorContainer }
                        StyledToolTip { text: Translation.tr("Force kill (SIGKILL)") }
                    }
                }
            }
        }
    }
}
