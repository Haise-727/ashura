import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Ashura: a panel that drops out of the bar, caelestia-style. Unlike
// StyledPopup it stays open while the pointer is on the panel too, so its
// contents (sliders, tabs, buttons) can be used.
//
// Two ways to open it:
//   targetHovered      bind to a bar item's hover (the volume icon's mixer)
//   triggerFraction    > 0: a thin strip on the very top edge of the screen,
//                      that fraction of its width, centred, opens it (the
//                      dashboard: the middle half of the top edge)
//
//   attached       the panel hangs flush from the bar (square top corners) and
//                  the bar's band above it counts as part of the panel, so the
//                  pointer can travel from the top edge down into it
//   graceMs        how long it stays after the pointer leaves
//   pinned         keep open regardless of hover; cleared when the pointer
//                  leaves the panel after visiting it
//   centerOnScreen centre it on the screen instead of under the item
Scope {
    id: root
    required property Item anchorItem
    property bool targetHovered: false
    property bool pinned: false
    property bool centerOnScreen: false
    property bool attached: false
    property real triggerFraction: 0
    property string namespace: "quickshell:hoverPanel"
    property int openDelay: 0                 // ms of hover before opening
    property int graceMs: 250
    default property alias content: body.data
    property real contentWidth: 300
    property real contentHeight: 200

    property bool panelHovered: false
    // Keeps an open panel open (never opens it): the bar's middle while the
    // pointer passes through it. The band over the bar takes no input, so the
    // workspaces and clock under it stay clickable.
    property bool holdHovered: false
    property bool triggerHovered: false
    property bool armed: false                // hover has lasted openDelay
    readonly property bool wanted: root.targetHovered || root.triggerHovered
    // Open is a state, not a formula: only the trigger (or pinning) opens the
    // panel. Hover on the panel or on the bar's middle only keeps an OPEN
    // panel open. While it slides shut it takes no input, so a pointer that
    // crosses it again does not bring it back and reaches what is beneath.
    property bool open: false
    readonly property bool shown: !GlobalStates.screenLocked && root.open
    readonly property real band: root.attached ? Appearance.sizes.barHeight : 0
    readonly property real fillet: root.attached ? Appearance.rounding.screenRounding : 0
    readonly property var screen: root.anchorItem?.QsWindow?.window?.screen ?? Quickshell.screens[0]

    function update() {
        if (root.pinned || (root.wanted && root.armed)) root.open = true;
        else if (root.open && !(root.panelHovered || root.holdHovered || grace.running)) root.open = false;
    }
    onWantedChanged: {
        if (wanted) {
            if (root.openDelay > 0) delay.restart(); else root.armed = true;
        } else {
            delay.stop();
            if (root.armed) grace.restart();
            root.armed = false;
        }
        root.update();
    }
    onArmedChanged: root.update()
    onPinnedChanged: root.update()
    // Leaving the bar's middle (on the way down from the top edge into the
    // panel) gets the same grace as leaving the edge strip; without it a slow
    // pointer crossing the gap under the workspace pills closed the panel.
    onHoldHoveredChanged: {
        if (!holdHovered) grace.restart();
        root.update();
    }
    onPanelHoveredChanged: {
        if (!panelHovered) { grace.restart(); root.pinned = false; }
        root.update();
    }
    onOpenChanged: if (!open) root.panelHovered = false

    Timer { id: delay; interval: root.openDelay; onTriggered: root.armed = root.wanted }
    Timer { id: grace; interval: root.graceMs; onTriggered: root.update() }

    // Fullscreen on this screen (a video, a game): the top edge stays quiet.
    readonly property bool fullscreenHere: Hyprland.monitorFor(root.screen)?.activeWorkspace?.hasFullscreen ?? false
    onFullscreenHereChanged: if (fullscreenHere) root.triggerHovered = false

    // The top-edge trigger strip (not while something is fullscreen).
    Loader {
        active: root.triggerFraction > 0 && !root.fullscreenHere
        sourceComponent: PanelWindow {
            screen: root.screen
            anchors { top: true; left: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: `${root.namespace}:trigger`
            WlrLayershell.layer: WlrLayer.Overlay
            implicitWidth: Math.round((screen?.width ?? 1920) * root.triggerFraction)
            implicitHeight: 3
            margins.left: Math.round(((screen?.width ?? 1920) - implicitWidth) / 2)
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: root.triggerHovered = containsMouse
            }
        }
    }

    PanelWindow {
        id: win
        screen: root.screen
        // Always mapped; closed it is empty and takes no input. Mapping the
        // window when it opened cost the first frames of the slide (jitter).
        visible: true
        color: "transparent"
        anchors { top: true; left: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: root.namespace
        WlrLayershell.layer: WlrLayer.Overlay
        // Keyboard only on demand while open: a click into a text field (the
        // dashboard's agenda) gets the keys; nothing is grabbed otherwise.
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        implicitWidth: root.contentWidth + Appearance.sizes.elevationMargin * 2 + root.fillet * 2
        implicitHeight: root.band + root.contentHeight + Appearance.sizes.elevationMargin * 2
        margins {
            top: root.attached ? 0 : Appearance.sizes.barHeight - Appearance.sizes.elevationMargin
            left: {
                const w = win.screen?.width ?? 1920;
                let x;
                if (root.centerOnScreen || !root.anchorItem?.QsWindow || !root.anchorItem?.Window?.window || !root.shown)
                    x = (w - win.implicitWidth) / 2;     // the bar item may not be in its window yet
                else {
                    // The bar item may not be in its window yet at start-up.
                    try { x = root.anchorItem.QsWindow.mapFromItem(root.anchorItem, root.anchorItem.width / 2, 0).x - win.implicitWidth / 2; }
                    catch (e) { x = (w - win.implicitWidth) / 2; }
                }
                return Math.max(0, Math.min(w - win.implicitWidth, x));
            }
        }
        mask: Region { item: root.shown ? inputArea : noInput }
        // Input only on the card and its corners, not on the band over the bar.
        Item {
            id: inputArea
            x: hoverArea.x
            y: hoverArea.y + root.band
            width: hoverArea.width
            height: root.contentHeight
        }
        Item { id: noInput; width: 0; height: 0 }

        // Everything lives inside hoverArea, and the HoverHandler sits on it, so
        // hover is seen through any child (tabs and sliders take hover for
        // themselves; a handler beside them lost it and the panel kept closing
        // and reopening).
        Item {
            id: hoverArea
            x: Appearance.sizes.elevationMargin
            y: root.attached ? 0 : Appearance.sizes.elevationMargin
            width: root.contentWidth + root.fillet * 2
            height: root.band + root.contentHeight
            HoverHandler { onHoveredChanged: root.panelHovered = hovered && root.open }

            // Attached: the card slides down out of the bar; detached: it drops
            // a little and fades in.
            Item {
                id: clipper
                x: root.fillet
                y: root.band
                width: root.contentWidth
                height: root.contentHeight
                clip: root.attached

                StyledRectangularShadow { target: card; opacity: card.reveal; visible: !root.attached }

                Rectangle {
                    id: card
                    property real reveal: root.shown ? 1 : 0
                    // Opening eases out; closing ends crisply (an OutQuint
                    // tail left the card and its corners hanging for a while).
                    Behavior on reveal { NumberAnimation { duration: root.attached ? 260 : 220; easing.type: root.shown ? Easing.OutQuint : Easing.InOutCubic } }
                    width: root.contentWidth
                    height: root.contentHeight
                    y: root.attached ? -(1 - reveal) * height : -(1 - reveal) * 16
                    // Attached panels slide without fading: a fade crosses
                    // Hyprland's blur cut-off and flashes.
                    opacity: root.attached ? 1 : reveal
                    topLeftRadius: root.attached ? 0 : Appearance.rounding.large
                    topRightRadius: root.attached ? 0 : Appearance.rounding.large
                    bottomLeftRadius: Appearance.rounding.large
                    bottomRightRadius: Appearance.rounding.large
                    color: root.attached ? Appearance.colors.colLayer0 : Appearance.m3colors.m3surfaceContainer
                    border.width: root.attached ? 0 : 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    Item {
                        id: body
                        anchors.fill: parent
                    }
                }
            }

            // Attached: inverted corners joining the card to the bar, the way
            // the bar joins the screen edges. They shrink with the visible
            // part of the card, so no ramps are left behind while it closes.
            // Gone before the card is: they shrink while the visible card
            // goes from two fillets tall to one.
            readonly property real filletNow: root.fillet * Math.max(0, Math.min(1, (card.reveal * root.contentHeight - root.fillet) / root.fillet))
            RoundCorner {
                visible: root.attached && hoverArea.filletNow > 0.5
                x: root.fillet - hoverArea.filletNow
                y: root.band
                implicitSize: hoverArea.filletNow
                color: Appearance.colors.colLayer0
                corner: RoundCorner.CornerEnum.TopRight
            }
            RoundCorner {
                visible: root.attached && hoverArea.filletNow > 0.5
                x: root.fillet + root.contentWidth
                y: root.band
                implicitSize: hoverArea.filletNow
                color: Appearance.colors.colLayer0
                corner: RoundCorner.CornerEnum.TopLeft
            }
        }
    }
}
