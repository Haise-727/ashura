pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura: background lofi radio for the startup workspace.
 *
 * Plays a stream with mpv (no video). mpv-mpris makes it an MPRIS player, so it
 * appears in the media card like any other player. Stations were checked to
 * answer with audio on 2026-11-08; add more to `stations`.
 */
Singleton {
    id: root

    readonly property var stations: [
        { name: "laut.fm lofi", url: "https://lofi.stream.laut.fm/lofi" },
        { name: "Nightwave Plaza", url: "https://radio.plaza.one/mp3" }
    ]
    property int stationIndex: 0
    readonly property bool playing: mpvProc.running
    readonly property string stationName: root.stations[root.stationIndex].name

    function play(index) {
        if (index !== undefined) root.stationIndex = index;
        mpvProc.running = false;
        mpvProc.command = ["mpv", "--no-video", "--really-quiet", `--title=${root.stationName}`,
            `--force-media-title=${root.stationName}`, root.stations[root.stationIndex].url];
        mpvProc.running = true;
    }
    function stop() { mpvProc.running = false; }
    function toggle() { root.playing ? root.stop() : root.play(); }
    function next() { root.play((root.stationIndex + 1) % root.stations.length); }

    Process { id: mpvProc }
}
