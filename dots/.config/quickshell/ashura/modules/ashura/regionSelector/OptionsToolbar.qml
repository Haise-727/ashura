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

    // Ashura: what the shot is for. Copy (and save) it, or send it to
    // Google Lens. Hidden for text recognition and recording.
    ToolbarTabBar {
        id: actionBar
        visible: root.action === RegionSelection.SnipAction.Copy || root.action === RegionSelection.SnipAction.Search
        tabButtonList: [
            {"icon": "content_copy", "name": Translation.tr("Copy")},
            {"icon": "image_search", "name": Translation.tr("Lens")}
        ]
        currentIndex: root.action === RegionSelection.SnipAction.Search ? 1 : 0
        onCurrentIndexChanged: {
            if (!actionBar.visible) return;
            root.action = currentIndex === 1 ? RegionSelection.SnipAction.Search : RegionSelection.SnipAction.Copy;
        }
    }
}
