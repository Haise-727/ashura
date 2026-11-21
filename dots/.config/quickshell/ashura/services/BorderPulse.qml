pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

/*
 * Ashura: the focused window's border follows the music, subtly (August spec:
 * "subtle waves on beat, with a toggle"). At rest it is the theme's own border
 * (outline_variant at 0x77, as matugen's Hyprland template writes it); with the
 * bass it shifts towards the accent and grows opaque. Sent to Hyprland over its
 * socket (Hyprland.dispatch, no process per update), only when the value moves,
 * at most ~12 times a second, and restored once when the music stops.
 * Toggle: `qs -c ashura ipc call borderPulse toggle`.
 */
Singleton {
    id: root
    property bool enabled: false   // Haise: no strobing border; it stays the solid resting colour
    readonly property bool active: root.enabled && CavaFeed.playing
    property int lastLevel: -1
    // The colour the active border has right now (the wave border fills with it).
    property color currentColour: Appearance.colors.colPrimary
    property real peak: 0.004

    function load() {}

    Binding { target: CavaFeed; property: "wantBorder"; value: root.enabled }

    function hex2(v) { return Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0"); }
    // Solid and bright, from the wallpaper (caelestia-style): the palette's
    // primary at rest, lifted towards a light tint of it on the bass.
    function colourFor(level) {               // level 0..16
        const t = level / 16;
        const a = Appearance.colors.colPrimary;
        const b = Qt.lighter(Appearance.colors.colPrimary, 1.45);
        const r = (a.r + (b.r - a.r) * t) * 255, g = (a.g + (b.g - a.g) * t) * 255, bl = (a.b + (b.b - a.b) * t) * 255;
        return `rgba(${hex2(r)}${hex2(g)}${hex2(bl)}ff)`;
    }
    function push(level, force) {
        if (level === root.lastLevel && !force) return;
        root.lastLevel = level;
        const t = level / 16;
        root.currentColour = Qt.rgba(
            Appearance.colors.colPrimary.r + (Qt.lighter(Appearance.colors.colPrimary, 1.45).r - Appearance.colors.colPrimary.r) * t,
            Appearance.colors.colPrimary.g + (Qt.lighter(Appearance.colors.colPrimary, 1.45).g - Appearance.colors.colPrimary.g) * t,
            Appearance.colors.colPrimary.b + (Qt.lighter(Appearance.colors.colPrimary, 1.45).b - Appearance.colors.colPrimary.b) * t, 1);
        Hyprland.dispatch(`function() hl.config({ general = { col = { active_border = "${root.colourFor(level)}" } } }) end`);
    }

    Timer {
        interval: 80
        repeat: true
        running: root.active
        // Auto-gain: the bass is measured against its own recent peak, so the
        // border moves the same with quiet or loud audio (on this laptop cava's
        // bass sat near 0.01 of its scale). The peak decays slowly and never
        // drops below a floor, so silence stays still.
        onTriggered: {
            root.peak = Math.max(CavaFeed.bass, root.peak * 0.985, 0.004);
            root.push(Math.round(Math.min(1, CavaFeed.bass / root.peak) * 16));
        }
    }
    onActiveChanged: if (!active) root.push(0)   // back to the resting colour
    // The resting colour is ours too: set it at start, when the wallpaper's
    // palette changes, and after Hyprland reloads its config (which brings back
    // the faint generated border).
    Component.onCompleted: Qt.callLater(() => root.push(0, true))
    Connections {
        target: Appearance.colors
        function onColPrimaryChanged() { root.push(root.lastLevel < 0 ? 0 : root.lastLevel, true); }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") reapply.restart();
        }
    }
    Timer { id: reapply; interval: 300; onTriggered: root.push(root.lastLevel < 0 ? 0 : root.lastLevel, true) }

    IpcHandler {
        target: "borderPulse"
        function toggle(): void { root.enabled = !root.enabled; }
        function state(): string { return `enabled=${root.enabled} active=${root.active} level=${root.lastLevel} peak=${root.peak.toFixed(3)} bass=${CavaFeed.bass.toFixed(3)} points=${CavaFeed.points.length}`; }
    }
}
