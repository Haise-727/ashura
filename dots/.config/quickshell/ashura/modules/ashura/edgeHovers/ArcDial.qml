import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Shapes
import Quickshell

// Ashura: the right edge's volume and brightness dial (panel style R2a). A half
// disc out of the screen edge with two arcs: volume outside, brightness inside.
// Each fills from the bottom up, its icon sits at its start and its number
// rides the end of the fill.
//
//   drag along an arc   set that value
//   scroll over it      change it by 5%
//   click elsewhere     `clicked()` (EdgeHovers opens the sidebar)
Item {
    id: root
    required property var screenRef
    signal clicked()

    readonly property real radius: 124
    implicitWidth: radius
    implicitHeight: radius * 2

    // Arc geometry, in degrees (0 = right, clockwise). Bottom end to top end.
    readonly property real a0: 104
    readonly property real a1: 256
    readonly property real span: a1 - a0
    readonly property real cx: width
    readonly property real cy: height / 2
    readonly property real rOuter: 98
    readonly property real rInner: 66
    readonly property real thick: 17

    readonly property var monitor: Brightness.getMonitorForScreen(root.screenRef)
    readonly property real vol: Audio.sink?.audio.volume ?? 0
    readonly property bool muted: Audio.sink?.audio.muted ?? false
    readonly property real volFrac: Math.max(0, Math.min(1, vol / Audio.maxVolume))
    readonly property real sun: monitor?.brightness ?? 0

    function setVol(f) { if (Audio.sink) Audio.sink.audio.volume = Math.max(0, Math.min(1, f)) * Audio.maxVolume; }
    function setSun(f) { root.monitor?.setBrightness(Math.max(0.01, Math.min(1, f))); }

    function pointAt(r, deg) {
        const a = deg * Math.PI / 180;
        return Qt.point(root.cx + Math.cos(a) * r, root.cy + Math.sin(a) * r);
    }

    // The half disc.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Appearance.colors.colLayer0
            strokeColor: "transparent"
            startX: root.cx; startY: root.cy - root.radius
            PathArc {
                x: root.cx; y: root.cy + root.radius
                radiusX: root.radius; radiusY: root.radius
                direction: PathArc.Counterclockwise
            }
        }
    }

    component Arc: Shape {
        id: arc
        property real r
        property real frac: 1
        property color colour
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: frac > 0.001
        ShapePath {
            fillColor: "transparent"
            strokeColor: arc.colour
            strokeWidth: root.thick
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.cx; centerY: root.cy
                radiusX: arc.r; radiusY: arc.r
                startAngle: root.a0
                sweepAngle: root.span * arc.frac
            }
        }
    }
    readonly property color sunColour: Qt.tint(Appearance.colors.colPrimary, Qt.alpha(Appearance.colors.colLayer0, 0.35))
    Arc { r: root.rOuter; colour: Appearance.colors.colLayer2 }
    Arc { r: root.rInner; colour: Appearance.colors.colLayer2 }
    Arc { r: root.rOuter; frac: root.volFrac; colour: root.muted ? Appearance.colors.colSubtext : Appearance.colors.colPrimary
        Behavior on frac { enabled: !drag.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
    Arc { r: root.rInner; frac: root.sun; colour: root.sunColour
        Behavior on frac { enabled: !drag.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }

    // Icons at the start of each arc, numbers riding the tips.
    // A round badge on the start of each arc, holding its icon.
    component StartIcon: Rectangle {
        id: start
        property real r
        property string text
        readonly property point p: root.pointAt(r, root.a0)
        x: p.x - width / 2; y: p.y - height / 2
        width: 26; height: 26; radius: 13
        color: Appearance.colors.colLayer0
        border.width: 2
        border.color: Appearance.colors.colLayer2
        MaterialSymbol {
            anchors.centerIn: parent
            text: start.text
            iconSize: 16
            fill: 1
            color: Appearance.colors.colOnLayer0
        }
    }
    StartIcon { r: root.rOuter; text: root.muted ? "volume_off" : "volume_up" }
    StartIcon { r: root.rInner; text: "light_mode" }

    component Tip: Rectangle {
        property real r
        property real frac
        property string label
        readonly property point p: root.pointAt(r, root.a0 + root.span * frac)
        x: p.x - width / 2; y: p.y - height / 2
        width: Math.max(28, tipText.implicitWidth + 10)
        height: 22
        radius: 11
        color: Appearance.colors.colOnLayer0
        StyledText {
            id: tipText
            anchors.centerIn: parent
            text: parent.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.family: Appearance.font.family.numbers
            font.weight: Font.DemiBold
            color: Appearance.colors.colLayer0
        }
    }
    Tip { r: root.rOuter; frac: root.volFrac; label: root.muted ? "×" : `${Math.round(root.vol * 100)}` }
    Tip { r: root.rInner; frac: root.sun; label: `${Math.round(root.sun * 100)}` }

    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: true
        property string ring: ""          // "vol" or "sun" while dragging
        property point pressAt
        function ringAt(x, y) {
            const d = Math.hypot(x - root.cx, y - root.cy);
            if (Math.abs(d - root.rOuter) < root.thick) return "vol";
            if (Math.abs(d - root.rInner) < root.thick) return "sun";
            return "";
        }
        function fracAt(x, y) {
            let deg = Math.atan2(y - root.cy, x - root.cx) * 180 / Math.PI;
            if (deg < 0) deg += 360;
            return Math.max(0, Math.min(1, (deg - root.a0) / root.span));
        }
        function apply(x, y) {
            if (ring === "vol") root.setVol(fracAt(x, y));
            else if (ring === "sun") root.setSun(fracAt(x, y));
        }
        onPressed: mouse => { ring = ringAt(mouse.x, mouse.y); pressAt = Qt.point(mouse.x, mouse.y); apply(mouse.x, mouse.y); }
        onPositionChanged: mouse => { if (pressed) apply(mouse.x, mouse.y); }
        onReleased: mouse => {
            const moved = Math.hypot(mouse.x - pressAt.x, mouse.y - pressAt.y) > 4;
            if (ring === "" && !moved) root.clicked();
            ring = "";
        }
        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            const d = Math.hypot(wheel.x - root.cx, wheel.y - root.cy);
            // Outer half of the disc is volume, the inner part brightness.
            if (d > (root.rOuter + root.rInner) / 2) root.setVol(root.volFrac + step / (Audio.maxVolume / 1));
            else root.setSun(root.sun + step);
        }
    }
}
