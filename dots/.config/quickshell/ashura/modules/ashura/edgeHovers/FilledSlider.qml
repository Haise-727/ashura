import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Templates as T

// Ashura: a tall pill slider that fills from the bottom, with its icon riding on
// the handle; while it moves the icon turns into the value. Adapted from
// caelestia's FilledSlider (GPL-3.0, github.com/caelestia-dots/shell) onto the shell's
// colours and animations.
T.Slider {
    id: root

    required property string icon
    property real displayScale: 100        // value * this is what the handle shows
    property bool moving: false
    property real oldValue
    property bool initialized: false

    orientation: Qt.Vertical
    implicitWidth: 36
    implicitHeight: 150

    background: Rectangle {
        color: Appearance.colors.colLayer2
        radius: width / 2

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            y: root.handle.y
            height: parent.height - y
            color: Appearance.m3colors.m3secondary
            radius: parent.radius
        }
    }

    handle: Item {
        y: root.visualPosition * (root.availableHeight - height)
        implicitWidth: root.width
        implicitHeight: root.width

        Rectangle {
            id: knob
            anchors.fill: parent
            radius: width / 2
            color: Appearance.m3colors.m3inverseSurface

            MaterialSymbol {
                id: glyph
                anchors.centerIn: parent
                visible: !root.moving
                text: root.icon
                fill: 1
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.m3colors.m3inverseOnSurface
            }
            StyledText {
                anchors.centerIn: parent
                visible: root.moving
                text: Math.round(root.value * root.displayScale)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.m3colors.m3inverseOnSurface
            }
        }
    }

    onPressedChanged: root.moving = pressed
    onValueChanged: {
        if (!root.initialized) { root.initialized = true; return; }
        if (Math.abs(value - oldValue) < 0.01) return;
        oldValue = value;
        root.moving = true;
        settle.restart();
    }

    Timer {
        id: settle
        interval: 600
        onTriggered: if (!root.pressed) root.moving = false
    }

    // Scrolling over the slider nudges it, like the volume keys.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const step = (root.to - root.from) / 30;
            const v = Math.max(root.from, Math.min(root.to, root.value + (event.angleDelta.y > 0 ? step : -step)));
            root.value = v;
            root.moved();
        }
    }
}
