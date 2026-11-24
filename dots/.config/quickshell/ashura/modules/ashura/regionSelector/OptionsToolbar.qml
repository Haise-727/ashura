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
    ToolbarTabButton {
        visible: root.action === RegionSelection.SnipAction.Copy || root.action === RegionSelection.SnipAction.Search
        current: root.action === RegionSelection.SnipAction.Search
        text: Translation.tr("Lens")
        materialSymbol: "image_search"
        onClicked: root.action = current ? RegionSelection.SnipAction.Copy : RegionSelection.SnipAction.Search
    }
}
