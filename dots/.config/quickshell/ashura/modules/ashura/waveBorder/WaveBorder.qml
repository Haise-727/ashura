import qs
import qs.services
import qs.modules.common
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Ashura: a sound wave as the focused window's border. Hyprland's own border
// can only change colour, so this draws a line around the focused window on a
// layer above it that takes no input; the music (shared cava, scaled to its
// peak) pushes the line outwards, the bass in the middle of the top and bottom
// edges, the highs at the corners, rippling slowly round. Flat and hidden when
// nothing plays; hidden for fullscreen windows.
// Toggle: `qs -c ashura ipc call waveBorder toggle`.
Scope {
    id: root
    property bool enabled: AshuraSettings.waveBorder   // Settings, Music
    readonly property bool playing: CavaFeed.playing
    readonly property bool active: root.enabled && root.playing
    readonly property int samples: 420          // points round the edge (smooth curves)
    readonly property real amplitude: 34        // px at full level, each way
    property real rounding: 18
    property real phase: 0
    // Smoothed levels of the control points round the edge (rise fast, fall
    // slowly), so the wave swells and settles instead of twitching.
    // Levels round the edge, fine-grained; each window places its own packets
    // from them (more on bigger windows, see `win.packets`).
    readonly property int controls: 96
    property var levels: []

    Binding { target: CavaFeed; property: "wantWave"; value: root.active }
    // Hide during a touchpad swipe: the workspace slides but the wave would not.
    Binding { target: TouchpadSwipe; property: "want"; value: root.active }

    // Hyprland's corner rounding, so the line follows the window's shape.
    Process {
        running: true
        command: ["hyprctl", "getoption", "decoration:rounding", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.rounding = JSON.parse(text).int ?? 18; } catch (e) {} }
        }
    }

    // Every frame: the slow drift, and the levels eased towards the music.
    Timer {
        interval: 16; repeat: true; running: root.active
        onTriggered: {
            root.phase += 0.008;
            const pts = CavaFeed.points, peak = CavaFeed.peak, bands = Math.min(30, pts.length);
            const next = [];
            for (let k = 0; k < root.controls; k++) {
                const f = k / root.controls;
                // bass at the middle of the top and bottom edges, highs at the corners
                const half = Math.abs(((f + 0.125) % 0.5) - 0.25) * 4;
                const band = Math.min(Math.max(0, bands - 1), Math.round(half * (bands - 1)));
                const target = bands > 0 ? Math.min(1, (pts[band] ?? 0) / peak) : 0;
                const cur = root.levels[k] ?? 0;
                next.push(cur + (target - cur) * (target > cur ? 0.35 : 0.06));
            }
            root.levels = next;
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "quickshell:waveBorder"
            WlrLayershell.layer: WlrLayer.Top
            visible: root.enabled

            readonly property var mon: HyprlandData.monitors.find(m => m.name === modelData.name)
            readonly property var focused: {
                const ws = mon?.activeWorkspace?.id;
                return HyprlandData.windowList.find(w => w.focusHistoryID === 0 && w.workspace?.id === ws && !w.hidden) ?? null;
            }
            // With no window or a single one, the wave runs along the screen's
            // edges below the bar instead of round a window.
            readonly property int windowCount: HyprlandData.windowList.filter(w => w.workspace?.id === mon?.activeWorkspace?.id && !w.hidden).length
            readonly property bool edgeMode: windowCount <= 1
            // Haise: no wave at all with zero or one window (edge mode is kept
            // in the code but never shown).
            readonly property bool show: root.active && !TouchpadSwipe.swiping && !edgeMode && focused !== null && (focused.fullscreen ?? 0) === 0
            readonly property real bw: 3                              // Hyprland's border width
            // Edge mode runs flush along the screen edges, right under the bar.
            readonly property real wx: edgeMode ? 0 : (focused?.at[0] ?? 0) - (mon?.x ?? 0) - bw
            readonly property real wy: edgeMode ? Appearance.sizes.barHeight : (focused?.at[1] ?? 0) - (mon?.y ?? 0) - bw
            readonly property real ww: edgeMode ? width : (focused?.size[0] ?? 0) + bw * 2
            readonly property real wh: edgeMode ? height - Appearance.sizes.barHeight : (focused?.size[1] ?? 0) + bw * 2
            readonly property real cornerR: edgeMode ? 1 : root.rounding + bw
            // Pointing inwards on the screen edges (outwards there is no room),
            // over a thin base band there so the dips show too.
            readonly property real dir: edgeMode ? -1 : 1
            readonly property real base: edgeMode ? 7 : 0
            // Solid, like a border: around a window the border's own live colour;
            // along the screen edges the bar's colour, so it reads as the bar
            // flowing down the sides.
            readonly property color fill: edgeMode ? Appearance.colors.colLayer0 : BorderPulse.currentColour

            // A point on the rounded rectangle at fraction f of its perimeter,
            // with its outward normal.
            function perimeterPoint(f) {
                const r = Math.min(win.cornerR, ww / 2, wh / 2);
                const sw = ww - 2 * r, sh = wh - 2 * r, arc = Math.PI * r / 2;
                const total = 2 * sw + 2 * sh + 4 * arc;
                let d = ((f % 1) + 1) % 1 * total;
                // top edge (left to right), then the corners and edges clockwise
                const segs = [
                    ["line", wx + r, wy, 1, 0, 0, -1, sw],
                    ["arc", wx + ww - r, wy + r, -Math.PI / 2, arc],
                    ["line", wx + ww, wy + r, 0, 1, 1, 0, sh],
                    ["arc", wx + ww - r, wy + wh - r, 0, arc],
                    ["line", wx + ww - r, wy + wh, -1, 0, 0, 1, sw],
                    ["arc", wx + r, wy + wh - r, Math.PI / 2, arc],
                    ["line", wx, wy + wh - r, 0, -1, -1, 0, sh],
                    ["arc", wx + r, wy + r, Math.PI, arc]
                ];
                for (const s of segs) {
                    const len = s[0] === "line" ? s[7] : s[4];
                    if (d <= len || s === segs[segs.length - 1]) {
                        if (s[0] === "line")
                            return [s[1] + s[3] * d, s[2] + s[4] * d, s[5], s[6]];
                        const a = s[3] + (d / r);
                        const nx = Math.cos(a), ny = Math.sin(a);
                        return [s[1] + nx * r, s[2] + ny * r, nx, ny];
                    }
                    d -= len;
                }
                return [wx, wy, 0, -1];
            }

            // The wave: each control point sends out a smooth wave packet (a
            // swell, a dip, a smaller swell under a soft envelope), the level of
            // its band setting the height; ripples drift slowly through the
            // packets. Smooth curves only, no corners.
            // One packet per ~48 px of this window's edge (24 to 96).
            readonly property int packets: Math.max(24, Math.min(96, Math.round((2 * ww + 2 * wh) / 48)))
            function wave(f) {
                const K = win.packets, lv = root.levels, L = root.controls;
                if (!lv.length) return 0;
                const x = f * K;
                let sum = 0;
                for (let d = -3; d <= 3; d++) {
                    const k = Math.round(x) + d, dist = x - k;
                    const kk = ((k % K) + K) % K;
                    const level = lv[Math.round(kk / K * L) % L] ?? 0;
                    sum += level * Math.exp(-(dist * dist) / 0.81) * Math.cos(2 * Math.PI * dist / 2.4 - root.phase * 3);
                }
                return Math.max(-1, Math.min(1, sum * 0.7));
            }
            // Two bands that never cross themselves: the swells (outwards) and
            // the dips (inwards), each between the border and the wave. One
            // self-crossing band dropped parts of its fill from frame to frame.
            readonly property var rings: {
                if (!show) return [[], []];
                const n = root.samples, outer = [], inner = [], edge = [];
                for (let i = 0; i <= n; i++) {
                    const f = i / n, p = perimeterPoint(f);
                    const off = win.dir * (win.base + wave(f) * root.amplitude);
                    const o = Math.max(0, off), d = Math.min(0, off);
                    outer.push(Qt.point(p[0] + p[2] * o, p[1] + p[3] * o));
                    inner.push(Qt.point(p[0] + p[2] * d, p[1] + p[3] * d));
                    edge.push(Qt.point(p[0], p[1]));
                }
                const back = edge.slice().reverse();
                return [outer.concat(back), inner.concat(back)];
            }

            Shape {
                anchors.fill: parent
                // No fade: it faded out and back whenever focus moved between
                // windows, which read as flicker.
                visible: win.show
                preferredRendererType: Shape.GeometryRenderer
                layer.enabled: true
                layer.samples: 4                       // smooth edges
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: win.fill
                    fillRule: ShapePath.OddEvenFill
                    PathPolyline { path: win.rings[0] }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: win.fill
                    fillRule: ShapePath.OddEvenFill
                    PathPolyline { path: win.rings[1] }
                }
            }
        }
    }

    IpcHandler {
        target: "waveBorder"
        function toggle(): void { root.enabled = !root.enabled; }
        function state(): string {
            return `active=${root.active} levels=${root.levels.map(v => v.toFixed(2)).join(",")} peak=${CavaFeed.peak.toFixed(0)} pts=${CavaFeed.points.slice(0, 6).join(",")}`;
        }
    }
}
