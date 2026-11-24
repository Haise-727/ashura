import qs.modules.common
import qs.modules.common.widgets
import QtQuick

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

    // Overlay to darken screen
    // Base dark overlay around region
    Rectangle {
        id: darkenOverlay
        z: 1
        visible: !root.breathingBorderOnly
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: root.regionX - darkenOverlay.border.width
            topMargin: root.regionY - darkenOverlay.border.width
        }
        width: root.regionWidth + darkenOverlay.border.width * 2
        height: root.regionHeight + darkenOverlay.border.width * 2
        color: "transparent"
        border.color: root.overlayColor
        border.width: Math.max(root.width, root.height)
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
