pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura: whether a touchpad swipe gesture is under way. Hyprland slides the
 * workspaces during a swipe without telling clients, so overlays drawn at a
 * window's resting place (the wave border) would stay behind; they hide while
 * `swiping`. Read from libinput (scripts/ashura/swipewatch), and only while
 * someone sets `want`, so nothing runs when no overlay needs it.
 * `swiping` stays true a little after the fingers lift, while the workspace
 * finishes its slide.
 */
Singleton {
    id: root
    property bool want: false
    property bool fingersDown: false
    readonly property bool swiping: fingersDown || settle.running

    Timer { id: settle; interval: 450 }

    Process {
        running: root.want
        command: [Quickshell.shellPath("scripts/ashura/swipewatch")]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("GESTURE_SWIPE_BEGIN")) {
                    root.fingersDown = true;
                } else if (line.includes("GESTURE_SWIPE_END")) {
                    root.fingersDown = false;
                    settle.restart();
                }
            }
        }
        onRunningChanged: if (!running) root.fingersDown = false
    }
}
