pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura: one shared cava for every music-reactive part (edge visualizer, shader
 * wallpaper, border pulse, startup dashboard, music card). Each part sets its want* flag
 * while it is shown; cava runs only while something wants it AND music plays.
 *
 * points: cava's raw bars, 0..1000 each (50 bars, bass first)
 * bass:   smoothed 0..1 level of the lowest bars
 */
Singleton {
    id: root
    property bool wantEdge: false
    property bool wantShader: false
    property bool wantBorder: false
    property bool wantDashboard: false
    property bool wantMusic: false        // the bottom-edge music card
    property bool wantRing: false         // the ring around the dashboard's cover
    property bool wantWave: false         // the wave border round the focused window
    readonly property bool playing: MprisController.activePlayer?.isPlaying ?? false
    readonly property bool running: (wantEdge || wantShader || wantBorder || wantDashboard || wantMusic || wantRing || wantWave) && playing

    property list<real> points: []
    property real bass: 0
    // A slowly decaying peak of all bars, so visualizers can scale to the music
    // instead of to cava's fixed 0..1000 (levels sit low on this laptop).
    property real peak: 30

    Process {
        id: cava
        running: root.running
        onRunningChanged: if (!running) { root.points = []; root.bass = 0; root.peak = 30; }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                const pts = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root.points = pts;
                root.peak = Math.max(pts.length ? Math.max(...pts) : 0, root.peak * 0.985, 30);
                const low = pts.slice(0, 8);
                const level = low.length ? low.reduce((a, b) => a + b, 0) / low.length / 1000 : 0;
                root.bass = root.bass * 0.6 + Math.min(1, level * 1.6) * 0.4;   // breathe, don't flicker
            }
        }
    }
}
