import qs.services
import qs.modules.common
import QtQuick

// Ashura: bars standing around a round album cover, caelestia-style, driven by
// the shared cava (scaled to its running peak). Mirrored: the bass sits at the
// top and bottom of the ring.
Item {
    id: root
    property real innerRadius: 70          // the cover's radius plus a small gap
    property real maxLength: 22
    property int count: 56
    property color color: Appearance.colors.colPrimary
    property bool active: true

    Binding { target: CavaFeed; property: "wantRing"; value: root.active && root.visible }

    implicitWidth: (innerRadius + maxLength) * 2
    implicitHeight: implicitWidth

    Repeater {
        model: root.count
        Rectangle {
            id: bar
            required property int index
            // fold the ring in half so both halves show the same bands
            readonly property int src: Math.round(Math.abs(((bar.index / root.count) * 2 % 2) - 1) * 30)
            readonly property real level: root.active ? Math.min(1, (CavaFeed.points[src] ?? 0) / CavaFeed.peak) : 0
            width: 3
            height: 2 + bar.level * root.maxLength
            radius: 1.5
            color: root.color
            opacity: 0.85
            // stands just outside the cover, rotated about the ring's centre
            x: root.width / 2 - width / 2
            y: root.height / 2 - root.innerRadius - height
            transform: Rotation {
                origin.x: bar.width / 2
                origin.y: bar.height + root.innerRadius
                angle: bar.index / root.count * 360
            }
            Behavior on height { NumberAnimation { duration: 70 } }
        }
    }
}
