import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

// Ashura: the desktop clock from the first Ashura shell, in place of the
// cookie clock. A big time and a small date over the wallpaper, below windows.
// It sits in the quietest (least detailed) region of the wallpaper and slides
// there when the wallpaper changes; its ink is light on dark regions and dark on
// bright ones (scripts/ashura/quiet-region.py works both out).
// Video wallpapers are measured from their thumbnail; shader wallpapers have no
// still image, so the clock goes bottom-right.
// Hidden on ws10, where the launch dashboard draws its own.
//
// It is drawn INSIDE the background window (Background.qml), above the
// wallpaper image: as a layer of its own it shared the Bottom level with the
// wallpaper, and whichever mapped last covered the other.
Item {
    id: root
    anchors.fill: parent
    property int size: AshuraSettings.clockSize          // Settings, Desktop clock
    property string measuredAnchor: "bottom-right"
    // "auto" follows the wallpaper's quietest corner; any other value pins a corner.
    readonly property string anchor: AshuraSettings.clockPlacement === "auto" ? measuredAnchor : AshuraSettings.clockPlacement
    property real luma: 0.2
    readonly property string wallpaper: Config.options.background.wallpaperPath
    readonly property bool isVideo: /\.(mp4|webm|mkv|mov|avi)$/i.test(wallpaper)
    readonly property bool isShader: /\.ashura$/i.test(wallpaper)
    readonly property string imageToMeasure: isVideo ? Config.options.background.thumbnailPath
        : isShader ? "" : wallpaper

    onImageToMeasureChanged: measure()
    Component.onCompleted: measure()

    // Where the clock sat on each wallpaper, so going back to one places it at
    // once, without measuring again (~/.cache/ashura/clock-positions.json).
    FileView {
        id: cacheFile
        path: `${FileUtils.trimFileProtocol(Directories.home)}/.cache/ashura/clock-positions.json`
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        onLoaded: root.measure()
        JsonAdapter {
            id: cache
            property var positions: ({})
        }
    }

    function measure() {
        if (!root.imageToMeasure) { root.measuredAnchor = "bottom-right"; root.luma = 0.2; return; }
        const hit = cache.positions[root.imageToMeasure];
        if (hit) { root.luma = hit.luma; root.measuredAnchor = hit.anchor; return; }
        quiet.running = false;
        quiet.measuring = root.imageToMeasure;
        quiet.command = [`${(Quickshell.env("ASHURA_VIRTUAL_ENV") || `${Quickshell.env("HOME")}/.local/state/quickshell/.venv`)}/bin/python`,
            `${FileUtils.trimFileProtocol(Directories.scriptPath)}/ashura/quiet-region.py`,
            root.imageToMeasure, "1920", "1080"];
        quiet.running = true;
    }
    Process {
        id: quiet
        property string measuring: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ");
                if (p.length < 6) return;
                root.luma = parseFloat(p[5]);
                root.measuredAnchor = p[0];          // last: the move follows it
                const positions = Object.assign({}, cache.positions);
                positions[quiet.measuring] = { anchor: p[0], luma: parseFloat(p[5]) };
                cache.positions = positions;
            }
        }
    }

    Item {
            id: win
            anchors.fill: parent
            visible: AshuraSettings.clockEnabled && HyprlandData.activeWorkspace?.id !== 10 && !GlobalStates.screenLocked

            readonly property bool atTop: root.anchor.startsWith("top")
            readonly property bool atBottom: root.anchor.startsWith("bottom")
            readonly property bool atLeft: root.anchor.endsWith("left")
            readonly property bool atRight: root.anchor.endsWith("right")
            readonly property bool bright: root.luma >= 0.5
            // The wallpaper colour's hue at a fixed lightness: light ink on dark
            // regions, dark ink on bright ones, whether the theme is light or
            // dark (the primary alone was dark-on-dark in light mode).
            readonly property color hueSrc: Appearance.colors.colPrimary
            property color fg: bright ? Qt.hsla(hueSrc.hslHue, Math.min(0.6, hueSrc.hslSaturation), 0.2, 1)
                                      : Qt.hsla(hueSrc.hslHue, Math.min(0.7, hueSrc.hslSaturation), 0.82, 1)
            property color subFg: bright ? Qt.rgba(0, 0, 0, 0.62) : Qt.rgba(1, 1, 1, 0.72)
            Behavior on fg { ColorAnimation { duration: 500 } }
            Behavior on subFg { ColorAnimation { duration: 500 } }

            Column {
                id: clockCol
                readonly property int pad: 56
                readonly property bool measured: width > 0 && height > 0
                spacing: Math.round(-root.size * 0.07)
                x: !measured ? win.width
                    : win.atLeft ? pad
                    : win.atRight ? win.width - width - pad
                    : (win.width - width) / 2
                y: !measured ? win.height
                    : win.atTop ? pad + Appearance.sizes.barHeight
                    : win.atBottom ? win.height - height - pad
                    : (win.height - height) / 2
                Behavior on x { enabled: clockCol.measured; NumberAnimation { duration: 650; easing.type: Easing.InOutCubic } }
                Behavior on y { enabled: clockCol.measured; NumberAnimation { duration: 650; easing.type: Easing.InOutCubic } }

                Text {
                    anchors.right: win.atRight ? parent.right : undefined
                    text: Qt.formatDateTime(DateTime.clock.date, AshuraSettings.clock24h ? "HH:mm" : "h:mm AP")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.size
                    font.bold: true
                    color: win.fg
                }
                Text {
                    visible: AshuraSettings.clockShowDate
                    anchors.right: win.atRight ? parent.right : undefined
                    text: Qt.formatDateTime(DateTime.clock.date, "dddd, dd MMMM")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.max(10, Math.round(root.size * 0.18))
                    color: win.subFg
                }
            }
    }
}
