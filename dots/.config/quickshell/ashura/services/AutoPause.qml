pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/*
 * Ashura: one player at a time (August spec, "youtube pausing spotify").
 * When any MPRIS player starts playing, every other playing player is paused.
 * The lofi radio (mpv) is a player too, so starting a video pauses it.
 *
 * A player that appears already playing (a freshly started app) never reports a
 * state change, so it is handled when it appears as well as on every change.
 */
Singleton {
    id: root

    function load() {   // called from shell.qml so the service starts at login
        console.log("[AutoPause] watching players");
    }

    function onlyThis(player) {
        if (!player.isPlaying) return;
        for (const other of Mpris.players.values) {
            if (other !== player && other.isPlaying && other.canPause) other.pause();
        }
    }

    // A player must keep playing for a moment before it pauses the others, so a
    // blip during a seek or a muted autoplay preview does not stop your music.
    Instantiator {
        model: Mpris.players
        delegate: Item {
            id: watcher
            required property MprisPlayer modelData
            Timer {
                id: settle
                interval: 1200
                onTriggered: if (watcher.modelData.isPlaying && watcher.modelData.volume !== 0) root.onlyThis(watcher.modelData)
            }
            Connections {
                target: watcher.modelData
                function onPlaybackStateChanged() { if (watcher.modelData.isPlaying) settle.restart(); else settle.stop(); }
            }
            Component.onCompleted: if (modelData.isPlaying) settle.restart()
        }
    }
}
