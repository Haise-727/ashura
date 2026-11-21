import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Ashura wallpaper picker (Super+Shift+W): a coverflow of skewed cards floating
// over the desktop. The card engine is pocket-dots' WallpaperPicker.qml (GPL-3.0,
// github.com/diegoMalagrida/pocket-dots), itself after ilyamiro's coverflow:
// fixed-width slots, each card animated only with scale and opacity by its
// distance to the centre, a fixed inner image that always covers the
// parallelogram.
//
// It lists every wallpaper in the chosen folder AND its subfolders
// (AshuraWallpapers). The chip on top switches between Normal (images) and Live
// (videos and shader wallpapers). Choosing one goes through the drawn transition.
//
// Keys: Left/Right or the wheel to move, Enter or a click on the middle card to
// apply, a click on a side card to bring it to the middle, Tab for Normal/Live,
// Esc or a click on empty space to close.
Scope {
    id: root
    property bool open: false
    property bool live: Wallpapers.liveMode
    readonly property var list: live ? AshuraWallpapers.lives : AshuraWallpapers.images
    readonly property string thumbScript: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/thumbnails/ashura-video-thumbs.sh`
    property int thumbsGen: 0                  // bumps when new thumbnails exist

    function apply(path) {
        root.open = false;
        AshuraWallpapers.apply(path);
    }
    function setLive(on) {
        root.live = on;
        Wallpapers.setLiveMode(on);            // the same choice the grid picker remembers
    }

    // The card image: the file itself for images; for videos the freedesktop
    // thumbnail (same name rule as ThumbnailImage); for shader wallpapers
    // their shipped preview.
    function thumbOf(path) {
        if (/\.ashura$/i.test(path)) {
            const name = path.split("/").pop().replace(/\.ashura$/i, "");
            return Quickshell.shellPath(`assets/ashura/shaders/${name}.png`);
        }
        if (/\.(mp4|webm|mkv|mov|avi)$/i.test(path)) {
            const uri = "file://" + path.split("/").map(encodeURIComponent).join("/");
            return `file://${FileUtils.trimFileProtocol(Directories.home)}/.cache/thumbnails/x-large/${Qt.md5(uri)}.png?${root.thumbsGen}`;
        }
        return "file://" + path;
    }

    Process {
        id: thumbsProc
        command: ["bash", "-c", `find -L '${StringUtils.shellSingleQuoteEscape(AshuraWallpapers.liveFolder)}' -type d | while read -r d; do bash '${root.thumbScript}' "$d" x-large >/dev/null; done`]
        onExited: root.thumbsGen++
    }

    onOpenChanged: {
        if (!open) return;
        AshuraWallpapers.rescan();
        if (root.live && !thumbsProc.running) thumbsProc.running = true;
        // Bring the current wallpaper to the middle.
        const i = root.list.indexOf(Config.options.background.wallpaperPath);
        carousel.currentIndex = i >= 0 ? i : 0;
        carousel.positionViewAtIndex(carousel.currentIndex, ListView.Center);
    }
    onLiveChanged: if (open && live && !thumbsProc.running) thumbsProc.running = true

    GlobalShortcut {
        name: "ashuraWallpaperPicker"
        description: "Ashura wallpaper picker (coverflow)"
        onPressed: root.open = !root.open
    }
    GlobalShortcut {
        name: "ashuraWallpaperRandom"
        description: "Random wallpaper (with the drawn transition)"
        onPressed: AshuraWallpapers.random(Wallpapers.liveMode)
    }
    IpcHandler {
        target: "ashuraPicker"
        function toggle(): void { root.open = !root.open; }
    }
    HyprlandFocusGrab { windows: [win]; active: root.open; onCleared: root.open = false }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open || stage.opacity > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:ashuraPicker"

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.open ? 210 : 110; easing.type: root.open ? Easing.OutCubic : Easing.InCubic } }
            onVisibleChanged: if (visible) forceActiveFocus()
            Connections { target: root; function onOpenChanged() { if (root.open) stage.forceActiveFocus(); } }

            Keys.onEscapePressed: root.open = false
            Keys.onLeftPressed: carousel.decrementCurrentIndex()
            Keys.onRightPressed: carousel.incrementCurrentIndex()
            Keys.onReturnPressed: carousel.applyCurrent()
            Keys.onEnterPressed: carousel.applyCurrent()
            Keys.onTabPressed: root.setLive(!root.live)
            WheelHandler {
                onWheel: e => {
                    if (e.angleDelta.y > 0 || e.angleDelta.x > 0) carousel.decrementCurrentIndex();
                    else carousel.incrementCurrentIndex();
                }
            }

            // A light veil so the cards read over any desktop; a click closes.
            Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.35 }
            MouseArea { anchors.fill: parent; onClicked: root.open = false }

            // Normal / Live
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Appearance.sizes.barHeight + 60
                spacing: 6
                Repeater {
                    model: [{ live: false, name: Translation.tr("Normal"), icon: "image" }, { live: true, name: Translation.tr("Live"), icon: "animated_images" }]
                    delegate: RippleButton {
                        required property var modelData
                        readonly property bool on: root.live === modelData.live
                        implicitHeight: 40
                        implicitWidth: chipRow.implicitWidth + 28
                        buttonRadius: 20
                        toggled: on
                        colBackground: Appearance.colors.colLayer0
                        colBackgroundToggled: Appearance.colors.colPrimary
                        onClicked: root.setLive(modelData.live)
                        contentItem: Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; iconSize: Appearance.font.pixelSize.larger
                                color: on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0 }
                            StyledText { anchors.verticalCenter: parent.verticalCenter; text: modelData.name
                                color: on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0 }
                        }
                    }
                }
            }

            ListView {
                id: carousel
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 12 }
                height: 560
                orientation: ListView.Horizontal
                model: root.list
                property real iw: 720
                property real ih: 406
                property real skew: -0.35
                property real bw: 3
                property real slotW: 360
                property real sideBase: 0.56
                readonly property real imgW: iw + ih * Math.abs(skew) + 12
                spacing: 0; clip: false; cacheBuffer: 2500
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - slotW) / 2
                preferredHighlightEnd: (width + slotW) / 2
                highlightMoveDuration: 420
                highlightMoveVelocity: 3000
                snapMode: ListView.SnapToItem
                boundsBehavior: Flickable.StopAtBounds
                maximumFlickVelocity: 6000

                function applyCurrent() {
                    if (currentIndex < 0 || currentIndex >= root.list.length) return;
                    root.apply(root.list[currentIndex]);
                }

                delegate: Item {
                    id: slot
                    required property string modelData
                    required property int index
                    width: carousel.slotW
                    height: carousel.height
                    readonly property real d: (x + width / 2 - (carousel.contentX + carousel.width / 2)) / carousel.slotW
                    readonly property real ad: Math.abs(d)
                    readonly property real sc: ad <= 1
                        ? carousel.sideBase + (1 - carousel.sideBase) * Math.pow(1 - ad, 1.35)
                        : carousel.sideBase * Math.pow(0.86, ad - 1)
                    z: Math.round(100 - ad * 10)
                    opacity: Math.max(0, Math.min(1, 1.15 - 0.34 * ad))

                    Item {
                        id: card
                        anchors.centerIn: parent
                        width: carousel.iw
                        height: carousel.ih
                        scale: slot.sc
                        transformOrigin: Item.Center
                        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, carousel.skew, 0, -carousel.skew * carousel.ih / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }

                        Rectangle {
                            anchors.fill: parent
                            color: Appearance.colors.colLayer0
                            border.width: slot.ad < 0.5 ? 2 : 1
                            border.color: slot.ad < 0.5 ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                        }
                        Item {
                            anchors.fill: parent; anchors.margins: carousel.bw; clip: true
                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: cardImg.status !== Image.Ready
                                text: /\.(mp4|webm|mkv|mov|avi)$/i.test(slot.modelData) ? "movie" : "image"
                                iconSize: 64
                                color: Appearance.colors.colSubtext
                            }
                            Image {
                                id: cardImg
                                anchors.centerIn: parent
                                width: carousel.imgW
                                height: carousel.ih
                                fillMode: Image.PreserveAspectCrop
                                source: root.thumbOf(slot.modelData)
                                asynchronous: true; cache: true; mipmap: true
                                sourceSize: Qt.size(carousel.imgW, carousel.ih)
                                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -carousel.skew, 0, carousel.skew * carousel.ih / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: slot.ad < 0.5 ? carousel.applyCurrent() : (carousel.currentIndex = slot.index)
                        }
                    }
                }
            }

            // The middle card's name, under the carousel
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: carousel.bottom
                anchors.topMargin: -40
                text: (root.list[carousel.currentIndex] ?? "").split("/").pop()
                color: "white"
                font.pixelSize: Appearance.font.pixelSize.large
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 1.0; blurMax: 16 }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.list.length === 0
                text: root.live ? Translation.tr("No live wallpapers in %1").arg(AshuraWallpapers.liveFolder)
                                : Translation.tr("No wallpapers in %1").arg(AshuraWallpapers.normalFolder)
                color: "white"
                font.pixelSize: Appearance.font.pixelSize.huge
            }
        }
    }
}
