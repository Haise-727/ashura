pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Options toolbar
Toolbar {
    id: root

    // Use a synchronizer on these
    property var action
    property var selectionMode
    // Signals
    signal dismiss()

    ToolbarTabBar {
        id: tabBar
        tabButtonList: [
            {"icon": "activity_zone", "name": Translation.tr("Rect")},
            {"icon": "gesture", "name": Translation.tr("Circle")}
        ]
        currentIndex: root.selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1
        onCurrentIndexChanged: {
            root.selectionMode = currentIndex === 0 ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle;
        }
    }

    // Ashura: one toggle. On, the shot goes to Google Lens; off, it is
    // copied. Hidden for text recognition and recording.
    // Its own on look: filled with the accent when on (a lone tab button has
    // no tab bar to draw the highlight behind it).
    RippleButton {
        id: lensToggle
        readonly property bool on: root.action === RegionSelection.SnipAction.Search
        visible: root.action === RegionSelection.SnipAction.Copy || root.action === RegionSelection.SnipAction.Search
        implicitHeight: 40
        implicitWidth: lensRow.implicitWidth + 20
        buttonRadius: height / 2
        colBackground: on ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
        colBackgroundHover: on ? Appearance.colors.colPrimaryHover : ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.95)
        onClicked: root.action = on ? RegionSelection.SnipAction.Copy : RegionSelection.SnipAction.Search
        contentItem: Row {
            id: lensRow
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                iconSize: 22
                text: "image_search"
                fill: lensToggle.on ? 1 : 0
                color: lensToggle.on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Lens")
                color: lensToggle.on ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
            }
        }
    }
}
