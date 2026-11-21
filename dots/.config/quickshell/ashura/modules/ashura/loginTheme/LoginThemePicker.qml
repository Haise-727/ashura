import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Ashura: pick the login screen theme. A centred card like the cheatsheet, with
// qylock's animated previews in a grid. A preview only plays while hovered, and
// only visible tiles are created, so the 38 GIFs cost little.
// Open with `/logintheme` in search or `qs -c ashura ipc call logintheme toggle`.
Scope {
    id: root

    Loader {
        id: pickerLoader
        active: false
        onActiveChanged: if (active) LoginTheme.refresh()

        sourceComponent: PanelWindow {
            id: pickerWindow
            visible: pickerLoader.active
            anchors { top: true; bottom: true; left: true; right: true }
            function hide() { pickerLoader.active = false; }
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:loginThemePicker"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"
            mask: Region { item: card }

            Component.onCompleted: GlobalFocusGrab.addDismissable(pickerWindow)
            Component.onDestruction: GlobalFocusGrab.removeDismissable(pickerWindow)
            Connections {
                target: GlobalFocusGrab
                function onDismissed() { pickerWindow.hide(); }
            }

            StyledRectangularShadow { target: card }

            Rectangle {
                id: card
                anchors.centerIn: parent
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Appearance.rounding.windowRounding
                property real padding: 20
                readonly property int columns: 4
                readonly property real tileWidth: 240
                readonly property real tileHeight: tileWidth * 9 / 16 + 34
                implicitWidth: columns * tileWidth + padding * 2
                implicitHeight: Math.min(pickerWindow.height - 120, header.implicitHeight + 2.6 * tileHeight + padding * 3)
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) pickerWindow.hide();
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: card.padding
                    spacing: 14

                    RowLayout {
                        id: header
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                text: Translation.tr("Login screen")
                                font.pixelSize: Appearance.font.pixelSize.title
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledText {
                                text: LoginTheme.themes.length > 0
                                    ? Translation.tr("Pick a theme. It shows at the next login; your password is asked once to change it.")
                                    : Translation.tr("qylock is not installed in ~/.local/share/ashura/qylock (the Ashura installer puts it there).")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }
                        RippleButton {
                            implicitWidth: 40
                            implicitHeight: 40
                            buttonRadius: Appearance.rounding.full
                            onClicked: pickerWindow.hide()
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: Appearance.font.pixelSize.title
                                text: "close"
                            }
                        }
                    }

                    GridView {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: card.tileWidth
                        cellHeight: card.tileHeight
                        model: LoginTheme.themes
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            id: tile
                            required property var modelData
                            readonly property bool isCurrent: LoginTheme.current === modelData.name
                            readonly property bool isBusy: LoginTheme.busy === modelData.name
                            width: grid.cellWidth
                            height: grid.cellHeight

                            RippleButton {
                                id: tileButton
                                anchors.fill: parent
                                anchors.margins: 6
                                buttonRadius: Appearance.rounding.normal
                                colBackground: tile.isCurrent ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                                enabled: LoginTheme.busy === ""
                                onClicked: if (!tile.isCurrent) LoginTheme.apply(tile.modelData.name)

                                contentItem: ColumnLayout {
                                    spacing: 6
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: (tileButton.width - 12) * 9 / 16
                                        Layout.margins: 6
                                        Layout.bottomMargin: 0
                                        radius: Appearance.rounding.small
                                        color: Appearance.colors.colLayer2
                                        clip: true
                                        AnimatedImage {
                                            id: preview
                                            anchors.fill: parent
                                            source: `file://${tile.modelData.previewA}`
                                            onStatusChanged: if (status === Image.Error && source.toString().indexOf(tile.modelData.previewB) === -1) source = `file://${tile.modelData.previewB}`
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: false
                                            playing: tileButton.hovered
                                        }
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: preview.status === Image.Error
                                            text: "image_not_supported"
                                            iconSize: 32
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                    RowLayout {
                                        Layout.leftMargin: 10
                                        Layout.rightMargin: 10
                                        Layout.bottomMargin: 6
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: tile.modelData.name
                                            elide: Text.ElideRight
                                            color: tile.isCurrent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                                        }
                                        MaterialSymbol {
                                            visible: tile.isCurrent || tile.isBusy
                                            text: tile.isBusy ? "hourglass_top" : "check_circle"
                                            fill: 1
                                            iconSize: Appearance.font.pixelSize.larger
                                            color: tile.isCurrent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "logintheme"
        function toggle(): void { pickerLoader.active = !pickerLoader.active; }
        function open(): void { pickerLoader.active = true; }
        function close(): void { pickerLoader.active = false; }
    }
}
