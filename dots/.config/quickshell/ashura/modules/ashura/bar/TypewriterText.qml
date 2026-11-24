import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Qt5Compat.GraphicalEffects

// Ashura: text that types itself in (panel style X13). Set `target`; the shown
// text deletes back to the part it shares with the new target, then types the
// rest. A change in the middle just aims at the new target from wherever it is,
// so a quick focus switch never stutters or restarts from empty.
// While it moves, the end of the text fades out softly (the letters fade in
// rather than pop). Each pass takes about `passMs` whatever the length.
StyledText {
    id: root
    property string target: ""
    property int passMs: 320
    readonly property bool moving: root.shown !== root.target
    property string shown: ""
    text: root.shown

    function commonPrefix(a, b) {
        let i = 0;
        while (i < a.length && i < b.length && a[i] === b[i]) i++;
        return i;
    }

    onTargetChanged: if (!tick.running) tick.start()
    Component.onCompleted: root.shown = root.target      // no type-in at start-up

    Timer {
        id: tick
        interval: 16
        repeat: true
        onTriggered: {
            const keep = root.commonPrefix(root.shown, root.target);
            if (root.shown.length > keep) {
                // Erase, twice as fast as typing.
                const n = Math.max(1, Math.ceil((root.shown.length - keep) * 16 / (root.passMs / 2)));
                root.shown = root.shown.slice(0, Math.max(keep, root.shown.length - n));
            } else if (root.shown.length < root.target.length) {
                const n = Math.max(1, Math.ceil((root.target.length - keep) * 16 / root.passMs));
                root.shown = root.target.slice(0, Math.min(root.target.length, root.shown.length + n));
            } else {
                tick.stop();
            }
        }
    }

    // The soft end: only while moving, so a still title renders plainly.
    layer.enabled: root.moving
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "white" }
                GradientStop { position: Math.max(0, Math.min(1, (root.contentWidth - 26) / Math.max(1, root.width))); color: "white" }
                GradientStop { position: Math.max(0.001, Math.min(1, root.contentWidth / Math.max(1, root.width))); color: "transparent" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
}
