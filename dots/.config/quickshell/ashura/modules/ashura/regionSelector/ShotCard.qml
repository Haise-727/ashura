import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Ashura: after a screenshot is copied, a small polaroid of it drops in at
// the top right, under the bar (panel style X12, without the tilt).
// Click it to open the shot in the editor (swappy); it slides back up on its
// own after a few seconds, and waits while the pointer is on it.
//
// The copy command calls `qs ipc call shotCard present <file>` once the file is
// written (modules/common/utils/ScreenshotAction.qml).
Scope {
    id: root
    property string file: ""
    property int serial: 0                  // a new shot reloads the image
    property bool up: false
    readonly property int stayMs: 5000

    function show(path) {
        root.file = path;
        root.serial++;
        root.up = true;
        stay.restart();
    }
    function edit() {
        if (root.file === "") return;
        const annotate = Config.options.regionSelector.annotation.useSatty ? "satty" : "swappy";
        Quickshell.execDetached(["bash", "-c", `${annotate} -f "$1"`, "_", root.file]);
        root.up = false;
    }

    Timer {
        id: stay
        interval: root.stayMs
        onTriggered: if (hover.hovered) stay.restart(); else root.up = false
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens[0]
        anchors { top: true; right: true }
        margins { top: Appearance.sizes.barHeight + 8; right: 16 }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell:shotCard"
        WlrLayershell.layer: WlrLayer.Overlay
        implicitWidth: card.width + 20
        implicitHeight: card.height + 20
        // Mapped only while the card is out or sliding.
        visible: root.up || card.slide < 1
        mask: Region { item: root.up ? card : null }

        Rectangle {
            id: card
            // 0 = in place, 1 = gone up past the top of the window.
            property real slide: root.up ? 0 : 1
            Behavior on slide { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
            x: 10
            y: 10 - slide * (height + 30)
            width: 240
            height: shot.height + 52
            radius: 6
            color: "#f4f1ea"                 // the paper
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.12)

            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.edit() }

            Rectangle {   // the photo
                x: 10; y: 10
                width: card.width - 20
                height: shot.height
                color: "#1b1b1b"
                clip: true
                Image {
                    id: shot
                    width: parent.width
                    height: Math.min(170, implicitHeight > 0 ? parent.width * implicitHeight / Math.max(1, implicitWidth) : 120)
                    fillMode: Image.PreserveAspectFit
                    source: root.file !== "" ? `file://${root.file}?${root.serial}` : ""
                    cache: false
                    asynchronous: true
                    sourceSize.width: 480
                }
            }
            Row {
                anchors { left: parent.left; leftMargin: 14; bottom: parent.bottom; bottomMargin: 12 }
                spacing: 6
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hover.hovered ? "edit" : "content_copy"
                    iconSize: 16
                    color: "#3a3a3a"
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hover.hovered ? Translation.tr("Click to edit") : Translation.tr("Copied")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: "#3a3a3a"
                }
            }
        }
    }

    IpcHandler {
        target: "shotCard"
        function present(path: string): void { root.show(path); }  // not "show": that is a qs ipc subcommand
        function hide(): void { root.up = false; }
    }
}
