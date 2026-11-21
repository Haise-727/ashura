import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

// Ashura: depth parallax for the wallpaper. scripts/ashura/depthlayers splits
// the picture by depth (Depth Anything V2) into three layers, each completed
// behind the nearer ones (LaMa); here they are drawn back to front, every pixel
// moved by its own depth: near things with the pointer, far things against it.
// If the layers are missing, the original picture is warped by the depth map
// alone (the fallback). Lives inside the background window over the wallpaper
// image, so the framing is identical; at rest it draws exactly the wallpaper.
//
// Only while it can be seen: an empty workspace, no transition, not locked, a
// still wallpaper. Otherwise hidden, its textures unloaded, and centred, so it
// comes back matching the wallpaper and eases to the pointer (no jump after a
// wallpaper change).
Item {
    id: root
    required property Item wallpaperItem       // the background's wallpaper image
    required property var monitor              // HyprlandMonitor of this screen
    anchors.fill: parent

    // Off (Haise, 2026-11-09): the filled-in backgrounds show as grey smudges
    // behind characters; every project doing this (shiftpaper, waydeeper,
    // Wallpaper Engine's depth parallax) shares the problem. Kept for later.
    property bool enabled: false
    property real maxShift: 30                  // px for the nearest pixel at the screen edge
    property real stillDepth: 0.35              // the depth that stays still
    property string folder: ""                  // depthlayers' cache folder for this wallpaper
    readonly property string wallpaper: Config.options.background.wallpaperPath
    // From HyprlandData (refreshed on every Hyprland event): the monitor
    // object's own activeWorkspace went stale and kept it off on empty workspaces.
    readonly property int wsId: (HyprlandData.monitors.find(m => m.name === root.monitor?.name)?.activeWorkspace?.id) ?? -1
    readonly property bool desktopClear: !HyprlandData.windowList.some(w => w.workspace?.id === root.wsId && !w.hidden)
    readonly property bool active: root.enabled && root.folder !== "" && root.desktopClear
        && !AshuraWallpapers.active && !GlobalStates.screenLocked && /\.(jpe?g|png|webp|bmp)$/i.test(root.wallpaper)

    onWallpaperChanged: lookup()
    Component.onCompleted: lookup()
    function lookup() {
        root.folder = "";
        prep.running = false;
        if (!root.enabled) return;                // nothing prepared while off
        if (!/\.(jpe?g|png|webp|bmp)$/i.test(root.wallpaper)) return;
        prep.forPath = root.wallpaper;
        prep.command = ["python3", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/ashura/depthlayers`, "get", root.wallpaper];
        prep.running = true;                     // first time per wallpaper ~20 s, then cached
    }
    Process {
        id: prep
        property string forPath: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (prep.forPath !== root.wallpaper) return;
                const f = text.trim().split("\n").pop();
                if (f.startsWith("/")) root.folder = f;
            }
        }
    }

    // Pointer over the desktop (the background only gets it where no window is).
    HoverHandler { id: pointer; enabled: root.enabled }
    property real targetX: (pointer.hovered && root.active) ? (pointer.point.position.x / Math.max(1, width) - 0.5) * 2 : 0
    property real targetY: (pointer.hovered && root.active) ? (pointer.point.position.y / Math.max(1, height) - 0.5) * 2 : 0
    property real px: 0
    property real py: 0
    Behavior on px { SmoothedAnimation { velocity: 1.6 } }
    Behavior on py { SmoothedAnimation { velocity: 1.6 } }
    onTargetXChanged: px = targetX
    onTargetYChanged: py = targetY

    component Tex: Image {
        required property string file
        visible: false
        asynchronous: true
        cache: false
        source: root.active && root.folder ? `file://${root.folder}/${file}` : ""
    }
    Tex { id: dispImg; file: "disp.png" }
    Tex { id: texL0; file: "layer0.png" }
    Tex { id: texL1; file: "layer1.png" }
    Tex { id: texL2; file: "layer2.png" }
    Tex { id: texD0; file: "depth0.png" }
    Tex { id: texD1; file: "depth1.png" }
    Tex { id: texD2; file: "depth2.png" }
    readonly property bool layersReady: [texL0, texL1, texL2, texD0, texD1, texD2].every(t => t.status === Image.Ready)

    ShaderEffect {
        x: root.wallpaperItem.x
        y: root.wallpaperItem.y
        width: root.wallpaperItem.width
        height: root.wallpaperItem.height
        visible: root.active && dispImg.status === Image.Ready && root.wallpaperItem.status === Image.Ready
        property var src: root.wallpaperItem
        property var dispTex: dispImg
        property var l0: texL0
        property var l1: texL1
        property var l2: texL2
        property var d0: texD0
        property var d1: texD1
        property var d2: texD2
        property real offx: root.px * root.maxShift / Math.max(1, width)
        property real offy: root.py * root.maxShift / Math.max(1, height)
        property real stillDepth: root.stillDepth
        property real mode: root.layersReady ? 1 : 0
        fragmentShader: Quickshell.shellPath("assets/ashura/shaders/parallax.v3.frag.qsb")
    }

    IpcHandler {
        target: "parallax"
        function state(): string {
            return `folder=${root.folder !== ""} clear=${root.desktopClear} fx=${AshuraWallpapers.active} active=${root.active} layers=${root.layersReady} disp=${dispImg.status} hovered=${pointer.hovered} px=${root.px.toFixed(2)}`;
        }
    }
}
