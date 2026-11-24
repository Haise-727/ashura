pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

/*
 * Ashura: what the music bar knows beyond MPRIS.
 *
 *   nextTitle / nextArtist   what plays next. Spotify only, through
 *                            scripts/ashura/ashura-spotify (Web API sign-in);
 *                            other players do not share their queue, so it
 *                            stays empty for them.
 *   liked / toggleLike()     Spotify songs: the Spotify library (when signed
 *                            in). Anything else, or Spotify without sign-in:
 *                            Ashura's own list, ~/.config/ashura/liked.json.
 *
 * It only asks Spotify while something shows it (`wanted`, the music bar).
 */
Singleton {
    id: root
    property bool wanted: false
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property string script: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/ashura/ashura-spotify`

    readonly property bool isSpotify: {
        const p = root.player;
        if (!p) return false;
        return `${p.identity ?? ""} ${p.desktopEntry ?? ""} ${p.dbusName ?? ""}`.toLowerCase().includes("spotify");
    }
    // "/com/spotify/track/<id>" or "spotify:track:<id>" -> "<id>"
    readonly property string spotifyId: {
        if (!root.isSpotify) return "";
        const raw = String(root.player?.metadata?.["mpris:trackid"] ?? "");
        const m = raw.match(/track[\/:]([A-Za-z0-9]+)$/);
        return m ? m[1] : "";
    }
    property bool spotifySignedIn: false

    property string nextTitle: ""
    property string nextArtist: ""
    property bool spotifyLiked: false

    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""
    readonly property bool useSpotifyLibrary: root.isSpotify && root.spotifySignedIn && root.spotifyId !== ""
    readonly property bool liked: root.useSpotifyLibrary ? root.spotifyLiked
        : localAdapter.items.some(it => it.title === root.title && it.artist === root.artist)

    function toggleLike() {
        if (root.title === "") return;
        if (root.useSpotifyLibrary) {
            root.spotifyLiked = !root.spotifyLiked;          // show it at once
            likeProc.command = [root.script, root.spotifyLiked ? "like" : "unlike", root.spotifyId];
            likeProc.running = true;
            return;
        }
        if (root.liked) {
            localAdapter.items = localAdapter.items.filter(it => !(it.title === root.title && it.artist === root.artist));
        } else {
            localAdapter.items = localAdapter.items.concat([{
                title: root.title, artist: root.artist,
                url: String(root.player?.metadata?.["xesam:url"] ?? ""),
                from: root.player?.identity ?? "", at: new Date().toISOString()
            }]);
        }
    }

    // ---- Spotify
    function refresh() {
        if (!root.wanted || !root.isSpotify || !root.spotifySignedIn) {
            root.nextTitle = ""; root.nextArtist = "";
            return;
        }
        if (!queueProc.running) queueProc.running = true;
        if (root.spotifyId !== "" && !likedProc.running) {
            likedProc.command = [root.script, "liked", root.spotifyId];
            likedProc.running = true;
        }
    }
    onWantedChanged: { if (wanted && !statusProc.running) statusProc.running = true; root.refresh(); }
    onSpotifyIdChanged: root.refresh()
    onIsSpotifyChanged: root.refresh()
    onSpotifySignedInChanged: root.refresh()
    Timer { interval: 15000; repeat: true; running: root.wanted && root.isSpotify && root.spotifySignedIn; onTriggered: root.refresh() }

    Process {
        id: statusProc
        command: [root.script, "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.spotifySignedIn = JSON.parse(text).signedIn === true; } catch (e) {} } }
    }
    Process {
        id: queueProc
        command: [root.script, "queue"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const q = JSON.parse(text);
                    const n = (q.next ?? [])[0];
                    root.nextTitle = n?.title ?? "";
                    root.nextArtist = n?.artist ?? "";
                } catch (e) {}
            }
        }
    }
    Process {
        id: likedProc
        stdout: StdioCollector { onStreamFinished: { try { const r = JSON.parse(text); if (r.liked !== undefined) root.spotifyLiked = r.liked; } catch (e) {} } }
    }
    Process { id: likeProc }

    // ---- Ashura's own liked list
    FileView {
        path: `${FileUtils.trimFileProtocol(Directories.home)}/.config/ashura/liked.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: localAdapter
            property list<var> items: []
        }
    }
}
