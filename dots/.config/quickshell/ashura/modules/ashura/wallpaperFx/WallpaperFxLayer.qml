import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell

// Ashura: draws a wallpaper change (state in services/AshuraWallpapers). Adapted
// from pocket-dots' WallpaperFx.qml (GPL-3.0, github.com/diegoMalagrida/pocket-
// dots); the shader is theirs too (assets/ashura/shaders/wallfx.frag).
// Drawn INSIDE the background window, right above the wallpaper image (a
// layer of its own shared the Bottom level with it, and the stacking order was
// whichever mapped last).
Item {
    id: win
    anchors.fill: parent

            readonly property bool loaded: oldImg.status === Image.Ready && newImg.status === Image.Ready
                && fieldImg.status === Image.Ready && lineImg.status === Image.Ready
            onLoadedChanged: if (loaded) AshuraWallpapers.screenReady()

            // Decoded at screen size, not file size.
            Image { id: oldImg; visible: false; asynchronous: true; cache: true   // cached: a chained change reuses the last new image
                source: AshuraWallpapers.oldPath ? "file://" + AshuraWallpapers.oldPath : ""
                sourceSize: Qt.size(win.width, win.height); fillMode: Image.PreserveAspectCrop }
            Image { id: newImg; visible: false; asynchronous: true; cache: true
                source: AshuraWallpapers.newPath ? "file://" + AshuraWallpapers.newPath : ""
                sourceSize: Qt.size(win.width, win.height); fillMode: Image.PreserveAspectCrop }
            // The maps hold numbers, not colours: contagion's are read texel by
            // texel (no filtering), the outline's are interpolated on purpose.
            Image { id: fieldImg; visible: false; asynchronous: true; cache: false
                smooth: AshuraWallpapers.kind === "perfil"
                source: AshuraWallpapers.fieldPath ? "file://" + AshuraWallpapers.fieldPath : "" }
            Image { id: lineImg; visible: false; asynchronous: true; cache: false
                source: AshuraWallpapers.linePath ? "file://" + AshuraWallpapers.linePath : "" }

            // Frame it exactly as the background does: cover the screen, then
            // zoom by its "workspace zoom" (1.07 by default), centred. A
            // different framing made the picture jump when the layer stepped
            // aside.
            readonly property real zoom: Config.options.background.parallax.workspaceZoom
            function crop(img) {
                const iw = Math.max(img.implicitWidth, 1), ih = Math.max(img.implicitHeight, 1);
                const s = Math.max(win.width / iw, win.height / ih) * win.zoom;
                const w = win.width / (iw * s), h = win.height / (ih * s);
                return Qt.vector4d((1 - w) / 2, (1 - h) / 2, w, h);
            }

            ShaderEffect {
                anchors.fill: parent
                visible: win.loaded && AshuraWallpapers.active
                opacity: AshuraWallpapers.fade
                property var oldTex: oldImg
                property var newTex: newImg
                property var fieldTex: fieldImg
                property var lineTex: lineImg
                property real t: AshuraWallpapers.t
                // 1 outline; for the rest 2 = ink (soft) or 0 = pixel colonies
                property real mode: AshuraWallpapers.kind === "perfil" ? 1 : (AshuraWallpapers.spreadStyle === "pixels" ? 0 : 2)
                property real sw: win.width
                property real sh: win.height
                property real fw: Math.max(fieldImg.implicitWidth, 1)
                property real fh: Math.max(fieldImg.implicitHeight, 1)
                property real lw: Math.max(lineImg.implicitWidth, 1)
                property real lh: Math.max(lineImg.implicitHeight, 1)
                property real glow: 0.9
                property real lineW: 1.5
                property real sdRange: 16
                property real seed: AshuraWallpapers.seed
                property vector4d cropOld: win.crop(oldImg)
                property vector4d cropNew: win.crop(newImg)
                property color ember: AshuraWallpapers.ember
                property color ink: AshuraWallpapers.ink
                fragmentShader: Quickshell.shellPath("assets/ashura/shaders/wallfx.v2.frag.qsb")
            }

}
