import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Shapes
import Quickshell

// Ashura: the on screen display for volume and brightness keys (panel style X3).
// Rings run out of the right screen edge and a small half disc shows the new
// value. `serial` changes on every key press, which restarts the rings.
Item {
    id: root
    required property string kind          // "volume" or "brightness"
    required property int serial
    required property var screenRef

    readonly property var monitor: Brightness.getMonitorForScreen(root.screenRef)
    readonly property bool isVol: kind === "volume"
    readonly property bool muted: isVol && (Audio.sink?.audio.muted ?? false)
    readonly property int value: Math.round((isVol ? (Audio.sink?.audio.volume ?? 0) : (monitor?.brightness ?? 0)) * 100)
    readonly property real cx: width
    readonly property real cy: height / 2

    property real phase: 0
    onSerialChanged: { ripple.restart(); }
    NumberAnimation on phase { id: ripple; from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic; running: false }

    // Three rings, a third of the way apart, each growing and fading.
    Repeater {
        model: 3
        delegate: Shape {
            id: ring
            required property int index
            readonly property real p: Math.max(0, Math.min(1, root.phase * 1.4 - index * 0.2))
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: (1 - p) * 0.85
            visible: p > 0 && p < 1
            ShapePath {
                fillColor: "transparent"
                strokeColor: Appearance.colors.colPrimary
                strokeWidth: 3 * (1 - ring.p) + 0.5
                PathAngleArc {
                    centerX: root.cx; centerY: root.cy
                    radiusX: 44 + ring.p * 120; radiusY: 44 + ring.p * 120
                    startAngle: 90; sweepAngle: 180
                }
            }
        }
    }

    // The value, in a half disc flush with the edge.
    Rectangle {
        x: root.cx - 44
        y: root.cy - 44
        width: 88
        height: 88
        radius: 44
        color: Appearance.colors.colLayer0
        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: 10
            width: 30
            spacing: 0
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.muted ? "×" : `${root.value}`
                font.pixelSize: Appearance.font.pixelSize.larger
                font.family: Appearance.font.family.numbers
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.isVol ? (root.muted ? "volume_off" : "volume_up") : "light_mode"
                iconSize: 16
                color: Appearance.colors.colPrimary
            }
        }
    }
}
