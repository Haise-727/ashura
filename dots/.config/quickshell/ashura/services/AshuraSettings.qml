pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura's own settings (~/.config/ashura/settings.json; its own file because
 * the main config loader drops keys it does not know). Edited in Settings, Music.
 */
Singleton {
    id: root
    property alias edgeVisualizer: adapter.edgeVisualizer
    property alias edgeVisualizerHideWithWindows: adapter.edgeVisualizerHideWithWindows
    property alias waveBorder: adapter.waveBorder
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
        }
    }
}
