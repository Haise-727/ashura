pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura's own settings (~/.config/ashura/settings.json; its own file because
 * the main config loader drops keys it does not know). Edited in Settings.
 */
Singleton {
    id: root
    property alias edgeVisualizer: adapter.edgeVisualizer
    property alias edgeVisualizerHideWithWindows: adapter.edgeVisualizerHideWithWindows
    property alias waveBorder: adapter.waveBorder
    // Edge panels (EdgeHovers)
    property alias edgeRight: adapter.edgeRight
    property alias edgeLeft: adapter.edgeLeft
    property alias edgeBottom: adapter.edgeBottom
    property alias edgeLeftDwellMs: adapter.edgeLeftDwellMs
    property alias edgeOsd: adapter.edgeOsd
    // Desktop clock (DesktopClock)
    property alias clockEnabled: adapter.clockEnabled
    property alias clockSize: adapter.clockSize
    property alias clockPlacement: adapter.clockPlacement
    property alias clock24h: adapter.clock24h
    property alias clockShowDate: adapter.clockShowDate
    // Dashboard (DashboardPanel)
    property alias dashboardGif: adapter.dashboardGif
    property alias dashboardBongoCat: adapter.dashboardBongoCat
    function load() {}

    FileView {
        path: `${FileUtils.trimFileProtocol(Directories.home)}/.config/ashura/settings.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: adapter
            property bool edgeVisualizer: true                   // the bars along the bottom edge
            property bool edgeVisualizerHideWithWindows: true    // off with 2+ windows (the wave border shows then)
            property bool waveBorder: true                       // the wave round the focused window
            property bool edgeRight: true                        // right edge: volume and brightness sliders
            property bool edgeLeft: true                         // left edge: the left sidebar
            property bool edgeBottom: true                       // bottom edge: the music bar
            property int edgeLeftDwellMs: 300                    // rest this long on the left edge for the rail
            property bool edgeOsd: true                          // show the sliders when volume or brightness changes
            property bool clockEnabled: true
            property int clockSize: 96                           // px, the time; the date is ~18% of it
            property string clockPlacement: "auto"               // auto (quietest corner) or top-left, top-right, bottom-left, bottom-right
            property bool clock24h: true
            property bool clockShowDate: true
            property string dashboardGif: ""                     // empty: the bundled gif
            property bool dashboardBongoCat: true                // the cat that plays along with music
        }
    }
}
