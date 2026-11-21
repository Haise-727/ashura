pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura: which shader live wallpaper is on, if any. Chosen in the wallpaper
 * picker's Live mode (an "<name>.ashura" file selects assets/ashura/shaders/
 * <name>.frag.qsb); choosing an image or video turns it off. Remembered in
 * ~/.local/state/ashura/live-shader across restarts.
 */
Singleton {
    id: root
    property string shader: ""
    readonly property bool active: root.shader.length > 0
    readonly property string stateFile: FileUtils.trimFileProtocol(`${Directories.home}/.local/state/ashura/live-shader`)

    function set(name) { root.shader = name; stateView.setText(name); }
    function clear() { if (root.active) { root.shader = ""; stateView.setText(""); } }
    function load() {}

    FileView {
        id: stateView
        path: root.stateFile
        printErrors: false
        onLoaded: root.shader = text().trim()
    }
}
