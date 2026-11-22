import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Virtual Keyboard")
    toggled: GlobalStates.oskOpen
    icon: toggled ? "keyboard_hide" : "keyboard"
    
    mainAction: () => {
        GlobalStates.sidebarRightOpen = false;   // Ashura: out of the way first
        GlobalStates.oskOpen = !GlobalStates.oskOpen
    }

    tooltipText: Translation.tr("On-screen keyboard")
}
