pragma Singleton

import qs.services
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/*
 * Ashura: synced lyrics for whatever is playing, like SekaiPop's lyrics widget.
 *
 * Looks the track up on LRCLIB (free, no key) once per track, keeps the synced
 * (LRC) version, and follows the player's position to give the current line.
 * YouTube-style titles ("Artist - Song (Official Video)") are cleaned up first.
 */
Singleton {
    id: root

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool playing: player?.isPlaying ?? false
    property var lines: []            // [{ t: seconds, text }]
    property int index: -1
    property string status: ""        // "", "searching", "none", "found"
    property string trackKey: ""

    // Optional chaining: lines and index change in separate steps on a new track.
    readonly property string current: lines[index]?.text ?? ""
    readonly property string previous: lines[index - 1]?.text ?? ""
    readonly property string next: index >= 0 ? (lines[index + 1]?.text ?? "") : ""

    function clean(title, artist) {
        let t = (title ?? "").replace(/\s*[\(\[][^\)\]]*(official|video|audio|lyric|mv|hd|4k|visuali[sz]er)[^\)\]]*[\)\]]/gi, "").trim();
        let a = (artist ?? "").replace(/\s*-\s*Topic$/i, "").replace(/VEVO$/i, "").trim();
        const dash = t.indexOf(" - ");
        if (dash > 0) {   // "Artist - Song" in the title wins over a channel name
            a = t.slice(0, dash).trim();
            t = t.slice(dash + 3).trim();
        }
        return { title: t, artist: a };
    }

    function parseLrc(text) {
        const out = [];
        for (const line of (text ?? "").split("\n")) {
            const m = line.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
            if (m) out.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), text: m[3] });
        }
        return out.filter(l => l.text.length > 0);
    }

    function fetch() {
        const p = root.player;
        if (!p) { root.index = -1; root.lines = []; root.status = ""; root.trackKey = ""; return; }
        const c = root.clean(p.trackTitle, p.trackArtist);
        const key = `${c.artist}|${c.title}`;
        if (c.title.length === 0) { root.index = -1; root.lines = []; root.status = ""; root.trackKey = ""; return; }
        if (key === root.trackKey && root.status !== "none") return;
        root.trackKey = key;
        root.index = -1;
        root.lines = [];
        root.status = "searching";
        const url = `https://lrclib.net/api/search?track_name=${encodeURIComponent(c.title)}` + (c.artist ? `&artist_name=${encodeURIComponent(c.artist)}` : "");
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || key !== root.trackKey) return;
            if (xhr.status !== 200) {
                // Offline or rate-limited: try again on the next track event.
                root.status = "";
                root.trackKey = "";
                return;
            }
            try {
                const results = JSON.parse(xhr.responseText).filter(r => r.syncedLyrics);
                const len = p.length > 0 ? p.length : 0;
                results.sort((x, y) => Math.abs(x.duration - len) - Math.abs(y.duration - len));
                root.lines = results.length > 0 ? root.parseLrc(results[0].syncedLyrics) : [];
            } catch (e) {
                root.lines = [];
            }
            root.status = root.lines.length > 0 ? "found" : "none";
        };
        xhr.send();
    }

    Connections {
        target: root.player
        function onTrackTitleChanged() { root.fetch(); }
        function onTrackArtistChanged() { root.fetch(); }
    }
    onPlayerChanged: fetch()
    Component.onCompleted: fetch()   // a track already playing when the shell starts

    // Follow the position while playing (MPRIS position has to be re-read).
    Timer {
        interval: 250
        repeat: true
        running: root.playing && root.lines.length > 0
        onTriggered: {
            root.player.positionChanged();
            const pos = root.player.position;
            let i = -1;
            for (let k = 0; k < root.lines.length; k++) {
                if (root.lines[k].t <= pos) i = k; else break;
            }
            root.index = i;
        }
    }
}
