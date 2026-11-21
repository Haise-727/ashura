pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura wallpapers: the folders, the lists, and the change itself.
 *
 * Folders (settings in ~/.config/ashura/wallpapers.json, its own file because
 * the main config loader drops keys it does not know):
 *   normalFolder  images; subfolders count too
 *   liveFolder    videos and .ashura shader wallpapers; subfolders count too
 *
 * The change: a still image replacing a still image (or a video, through its
 * thumbnail) gets a drawn transition, adapted from pocket-dots' wallfx
 * (GPL-3.0, github.com/diegoMalagrida/pocket-dots): if the new wallpaper has a
 * character, a thin line draws its outline first and the rest grows out of it;
 * otherwise it spreads in as pixel colonies. scripts/ashura/wallfx makes the
 * maps (the cut-out is cached per image; `prepare()` does a whole folder ahead
 * of time). The layer that draws it is modules/ashura/wallpaperFx.
 *
 * Hand-over with the background: the layer fades in showing the OLD wallpaper, the
 * apply (switchwall.sh: image + colours) runs underneath, the transition plays,
 * and the layer steps aside only once the config names the new wallpaper.
 * Anything that goes wrong falls back to a plain change: the wallpaper must
 * change even when the effect cannot be shown.
 */
Singleton {
    id: root

    // ---------------------------------------------------------------- settings
    readonly property string home: FileUtils.trimFileProtocol(Directories.home)
    readonly property string settingsPath: `${home}/.config/ashura/wallpapers.json`
    property alias normalFolder: settings.normalFolder
    property alias liveFolder: settings.liveFolder
    property alias transitions: settings.transitions
    // For wallpapers without a character: "ink" (a soft bleed) or "pixels"
    // (pocket-dots' pixel colonies).
    property alias spreadStyle: settings.spreadStyle

    FileView {
        id: settingsFile
        path: root.settingsPath
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: settings
            property string normalFolder: `${FileUtils.trimFileProtocol(Directories.home)}/Pictures/Wallpapers`
            property string liveFolder: `${FileUtils.trimFileProtocol(Directories.home)}/Pictures/Wallpapers/Live`
            property bool transitions: true
            property string spreadStyle: "ink"
        }
    }

    // ---------------------------------------------------------------- lists
    readonly property list<string> imageExts: ["jpg", "jpeg", "png", "webp", "avif", "bmp"]
    readonly property list<string> liveExts: ["mp4", "webm", "mkv", "mov", "avi", "ashura"]
    property list<string> images: []
    property list<string> lives: []

    function rescan() { scanImages.running = false; scanImages.running = true; scanLives.running = false; scanLives.running = true; }
    onNormalFolderChanged: rescan()
    onLiveFolderChanged: rescan()
    Component.onCompleted: rescan()
    function load() {}

    function findCmd(folder, exts, exclude) {
        const names = exts.map(e => `-iname '*.${e}'`).join(" -o ");
        const skip = exclude ? `-not -path '${StringUtils.shellSingleQuoteEscape(exclude)}/*'` : "";
        return ["bash", "-c", `find -L '${StringUtils.shellSingleQuoteEscape(folder)}' -type f \\( ${names} \\) ${skip} 2>/dev/null | sort`];
    }
    Process {
        id: scanImages
        // The live folder may sit inside the normal one (it does by default):
        // its thumbnails and previews are not wallpapers of the normal kind.
        command: root.findCmd(root.normalFolder, root.imageExts, root.liveFolder)
        stdout: StdioCollector { onStreamFinished: root.images = text.split("\n").filter(l => l.length > 0) }
    }
    Process {
        id: scanLives
        command: root.findCmd(root.liveFolder, root.liveExts, "")
        stdout: StdioCollector { onStreamFinished: root.lives = text.split("\n").filter(l => l.length > 0) }
    }

    function random(live) {
        const list = live ? root.lives : root.images;
        if (list.length === 0) return;
        const current = Config.options.background.wallpaperPath;
        let pick = list[Math.floor(Math.random() * list.length)];
        if (pick === current && list.length > 1) pick = list[(list.indexOf(pick) + 1) % list.length];
        root.apply(pick);
    }

    // ---------------------------------------------------------------- change
    readonly property string wallfx: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/ashura/wallfx`
    function isStill(p) { return /\.(jpe?g|png|webp|bmp)$/i.test(p ?? ""); }
    function isVideo(p) { return /\.(mp4|webm|mkv|mov|avi)$/i.test(p ?? ""); }

    // A change asked for while one is running interrupts it: the running one
    // rushes to its end (~150 ms) and the new one starts from that very frame,
    // with the effect covering the screen throughout. Nothing waits in a queue,
    // and pressing again and again always follows the latest press.
    property string retarget: ""

    function apply(path) {
        path = FileUtils.trimFileProtocol(path);
        if (choose.running && !root.active) {          // still choosing: it picks up the new one
            root.pendingNew = path;
            return;
        }
        if (root.active) {
            if (path === root.newPath) return;
            root.retarget = path;
            if (run.running) {
                run.stop();
                rush.from = root.t;
                rush.restart();                        // -> chain()
            } else if (!rush.running) {
                root.chain();
            }
            return;
        }
        const current = Config.options.background.wallpaperPath;
        const oldStill = root.isVideo(current) ? Config.options.background.thumbnailPath : current;
        if (!root.transitions || !root.isStill(path) || !root.isStill(oldStill) || path === current) {
            Wallpapers.apply(path);
            return;
        }
        root.pendingOld = oldStill;
        root.pendingNew = path;
        root.startChoose(path);
    }
    // Never killed half-way (a killed run reported an empty answer and broke the
    // state): if a newer wallpaper was asked for meanwhile, the answer is dropped
    // and the newer one is prepared instead.
    function startChoose(path) {
        choose.forPath = path;
        choose.command = ["python3", root.wallfx, "elige", path];
        choose.running = true;
        chooseWatchdog.restart();
    }
    property string pendingOld: ""
    property string pendingNew: ""
    Process {
        id: choose
        property string forPath: ""
        // "perfil <map> <line>" or "contagio <map> <smooth>"
        stdout: StdioCollector {
            onStreamFinished: {
                chooseWatchdog.stop();
                if (root.pendingNew && choose.forPath !== root.pendingNew) {
                    Qt.callLater(() => root.startChoose(root.pendingNew));
                    return;
                }
                const p = text.trim().split(/\s+/);
                if (p.length < 3 || !root.pendingNew) { root.plain(root.pendingNew); return; }
                root.prepare(root.pendingOld, root.pendingNew, p[0], p[1], p[2]);
            }
        }
    }
    // A new wallpaper is cut out on the spot (~10 s on the CPU) the first time;
    // past this, it changes plainly instead.
    Timer {
        id: chooseWatchdog
        interval: 30000
        onTriggered: { choose.running = false; root.plain(root.pendingNew); }
    }
    function plain(p) {
        if (p) Wallpapers.apply(p);
        root.pendingNew = "";
    }

    // The running transition stands at its end (the screen shows its new
    // wallpaper through the effect): start the next one from there.
    property bool chaining: false
    function chain() {
        const next = root.retarget;
        root.retarget = "";
        if (!next) return;
        fadeIn.stop(); fadeOut.stop(); settle.stop();
        root.fade = 1;
        root.t = 1;
        root.chaining = true;
        root.pendingOld = root.newPath;
        root.pendingNew = next;
        if (!root.transitions || !root.isStill(next)) {    // a video or shader: no effect, step aside
            root.chaining = false;
            root.finish();
            Wallpapers.apply(next);
            return;
        }
        watchdog.restart();                           // never stuck covering the screen
        if (!choose.running) root.startChoose(next);  // else its answer hands over to `next`
    }
    NumberAnimation { id: rush; target: root; property: "t"; to: 1; duration: 150; easing.type: Easing.OutQuad
        onFinished: root.chain() }

    // ---- the transition's state, read by modules/ashura/wallpaperFx
    property int msContagion: 1800
    property int msOutline: 2000
    property int msFade: 130
    property string oldPath: ""
    property string newPath: ""
    property string kind: "contagio"          // "contagio" | "perfil"
    property string fieldPath: ""
    property string linePath: ""
    property string phase: "idle"             // idle, loading, run, held, fadeout
    readonly property bool active: phase !== "idle"
    property real t: 0
    property real fade: 0
    property bool swapped: false
    property color ember: "orange"
    property color ink: "white"
    property real seed: 0
    property int screensReady: 0

    function prepare(o, n, k, f, l) {
        const chained = root.chaining;
        root.chaining = false;
        if (root.active && !chained) root.finish();
        root.oldPath = o; root.newPath = n;
        root.kind = k === "perfil" ? "perfil" : "contagio";
        root.fieldPath = f; root.linePath = l || f;
        root.t = 0; root.swapped = false; root.screensReady = 0;
        if (!chained) root.fade = 0;              // chained: the effect keeps covering
        root.phase = "loading";
        watchdog.restart();
    }
    // Each screen's layer reports when its four images have loaded.
    function screenReady() {
        if (root.phase !== "loading") return;
        root.screensReady++;
        if (root.screensReady < Quickshell.screens.length) return;
        watchdog.stop();
        root.go();
    }
    function lifted(c) {
        return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.55), Math.min(Math.max(c.hslLightness, 0.62), 0.82), 1);
    }
    function go() {
        // Captured now, not bound: the palette changes halfway through.
        root.ember = root.lifted(Appearance.colors.colPrimary);
        root.ink = Appearance.m3colors.m3onSurface;
        root.seed = Math.random() * 100;
        root.phase = "run";
        run.duration = root.kind === "perfil" ? root.msOutline : root.msContagion;
        run.restart();
        // Already covering (chained): switch the background underneath right away.
        if (root.fade >= 0.99) Wallpapers.apply(root.newPath);
        else fadeIn.restart();
    }
    function maybeFinish() {
        if (run.running || rush.running) return;
        if (root.retarget) { root.chain(); return; }
        if (!root.swapped) { root.phase = "held"; watchdog.restart(); return; }
        root.phase = "fadeout";
        fadeOut.restart();
    }
    function finish() {
        fadeIn.stop(); run.stop(); fadeOut.stop(); watchdog.stop(); settle.stop();
        root.phase = "idle"; root.fade = 0; root.t = 0;
        root.oldPath = ""; root.newPath = ""; root.fieldPath = ""; root.linePath = "";
        root.pendingNew = "";
        root.retarget = "";
        root.chaining = false;
        rush.stop();
    }

    // Fully covered: switch the background's wallpaper underneath.
    NumberAnimation { id: fadeIn; target: root; property: "fade"; from: 0; to: 1; duration: root.msFade; easing.type: Easing.OutQuad
        onFinished: Wallpapers.apply(root.newPath) }
    NumberAnimation { id: run; target: root; property: "t"; from: 0; to: 1; easing.type: Easing.Linear
        onFinished: root.maybeFinish() }
    NumberAnimation { id: fadeOut; target: root; property: "fade"; from: 1; to: 0; duration: root.msFade; easing.type: Easing.OutQuad
        onFinished: root.finish() }

    // The new path is written to the config once the background has the image;
    // give it a moment to draw it before anything uncovers it.
    Connections {
        target: Config.options.background
        function onWallpaperPathChanged() {
            if (root.active && Config.options.background.wallpaperPath === root.newPath) settle.restart();
        }
    }
    // The background measures the new image after loading it and then animates its size and
    // position for 600 ms; stay on the (identical) last frame until that is over.
    Timer { id: settle; interval: 1400; onTriggered: { root.swapped = true; root.maybeFinish(); } }

    // Stuck loading: change plainly. Stuck waiting for the background: step aside anyway.
    Timer {
        id: watchdog
        interval: 6000
        onTriggered: {
            const n = root.newPath, loading = root.phase === "loading";
            root.finish();
            if (loading && n) Wallpapers.apply(n);
        }
    }

    // ---------------------------------------------------------------- prepare
    // Cut out the characters of a whole folder ahead of time, so no change has
    // to wait for it. Settings has a button for this; it also runs when the
    // folder setting changes.
    property bool preparing: preparer.running
    property string prepareLog: ""
    function prepareAll() {
        if (preparer.running) return;
        root.prepareLog = "";
        preparer.command = ["nice", "-n", "19", "python3", root.wallfx, "warm", root.normalFolder];
        preparer.running = true;
    }
    Process {
        id: preparer
        stdout: SplitParser { onRead: line => root.prepareLog = line }
        onExited: (code) => root.prepareLog = code === 0 ? Translation.tr("All wallpapers are ready") : Translation.tr("Stopped (code %1)").arg(code)
    }

    IpcHandler {
        target: "ashuraWallpapers"
        function random(): void { root.random(false); }
        function randomLive(): void { root.random(true); }
        function apply(path: string): void { root.apply(path); }
        function prepare(): void { root.prepareAll(); }
        function state(): string { return root.phase; }
        function count(): string { return `${root.images.length} images, ${root.lives.length} live`; }
    }
}
