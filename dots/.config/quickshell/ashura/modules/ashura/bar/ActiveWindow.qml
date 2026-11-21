import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Ashura: the active window's name is also the search button. It shows the
// focused window's title (or "Search" on an empty workspace) next to a search
// icon, and a click opens search, so search is reachable with the mouse.
// The small line above says which app, or "cockpit · <repo>" inside the cockpit.
MouseArea {
    id: root
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    property string activeWindowAddress: `0x${activeWindow?.HyprlandToplevel?.address}`
    property bool focusingThisMonitor: HyprlandData.activeWorkspace?.monitor == monitor?.name
    property var biggestWindow: HyprlandData.biggestWindowForWorkspace(HyprlandData.monitors[root.monitor?.id]?.activeWorkspace.id)
    readonly property bool hasWindow: (root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow) || !!root.biggestWindow
    readonly property bool inCockpit: (monitor?.activeWorkspace?.id ?? 0) > 100 && (monitor?.activeWorkspace?.id ?? 0) <= 110

    implicitWidth: rowLayout.implicitWidth
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        anchors.leftMargin: -6
        radius: Appearance.rounding.full
        color: root.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"
        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 8

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: "search"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer0
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: -4

            StyledText {
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.inCockpit ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                elide: Text.ElideRight
                text: root.inCockpit ? `cockpit · ${Cockpit.currentName || Translation.tr("no repo")}`
                    : root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow
                        ? root.activeWindow?.appId : (root.biggestWindow?.class) ?? Translation.tr("Desktop")
            }

            StyledText {
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
                text: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow
                    ? root.activeWindow?.title
                    : (root.biggestWindow?.title) ?? Translation.tr("Search")
            }
        }
    }
}
