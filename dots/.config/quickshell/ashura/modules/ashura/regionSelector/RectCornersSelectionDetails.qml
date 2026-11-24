import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root
    required property real regionX
    required property real regionY
    required property real regionWidth
    required property real regionHeight
    required property color color
    required property color overlayColor
    property bool showSize: true
    property real cornerRadius: 4

    property bool breathingBorderOnly: false

    // The dim over everything but the selection, cut out with the
    // selection's own rounding (a mask, as caelestia does).
    Rectangle {
        id: darkenOverlay
        z: 1
        anchors.fill: parent
        visible: !root.breathingBorderOnly
        color: root.overlayColor
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: holeWrap
            invert: true
        }
    }
    Item {
        id: holeWrap
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            x: root.regionX
            y: root.regionY
            width: Math.max(0, root.regionWidth)
            height: Math.max(0, root.regionHeight)
            radius: root.cornerRadius
        }
    }

    // The selection: a solid accent outline round the clear area.
    Rectangle {
        id: selectionBorder
        z: 9
        readonly property int borderWidth: 2
        x: Math.round(root.regionX) - borderWidth
        y: Math.round(root.regionY) - borderWidth
        width: Math.round(root.regionWidth) + borderWidth * 2
        height: Math.round(root.regionHeight) + borderWidth * 2
        visible: root.regionWidth > 1 && root.regionHeight > 1
        radius: root.cornerRadius + borderWidth
        color: "transparent"
        border.color: root.color
        border.width: borderWidth

        // Breathing while recording
        opacity: 0.95
        SequentialAnimation on opacity {
            running: root.breathingBorderOnly
            loops: Animation.Infinite
            NumberAnimation { from: 0.9; to: 0.3; duration: 1200; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.3; to: 0.9; duration: 1200; easing.type: Easing.InOutQuad }
        }
    }

    StyledText {
        z: 2
        visible: !root.breathingBorderOnly && root.showSize
        anchors {
            top: selectionBorder.bottom
            right: selectionBorder.right
            margins: 8
        }
        color: root.color
        text: `${Math.round(root.regionWidth)} x ${Math.round(root.regionHeight)}`
    }
}
