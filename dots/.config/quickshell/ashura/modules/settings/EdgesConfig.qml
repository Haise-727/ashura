import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Ashura: the panels that open from the screen edges (modules/ashura/edgeHovers).
// Saved in ~/.config/ashura/settings.json (services/AshuraSettings).
ContentPage {
    forceWidth: true

    ContentSection {
        icon: "border_outer"
        title: Translation.tr("Screen edges")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("Each edge opens a panel when the pointer rests on it. The dashboard on the top edge is set in the bar's own settings.")
        }
        ConfigSwitch {
            buttonIcon: "tune"
            text: Translation.tr("Right edge: volume and brightness sliders (click for the sidebar)")
            checked: AshuraSettings.edgeRight
            onCheckedChanged: AshuraSettings.edgeRight = checked
        }
        ConfigSwitch {
            buttonIcon: "notifications_active"
            enabled: AshuraSettings.edgeRight
            text: Translation.tr("Show the sliders for a moment when volume or brightness changes")
            checked: AshuraSettings.edgeOsd
            onCheckedChanged: AshuraSettings.edgeOsd = checked
        }
        ConfigSwitch {
            buttonIcon: "left_panel_open"
            text: Translation.tr("Left edge: an icon rail for the translator, booru and screen translation")
            checked: AshuraSettings.edgeLeft
            onCheckedChanged: AshuraSettings.edgeLeft = checked
        }
        ConfigSwitch {
            buttonIcon: "music_note"
            text: Translation.tr("Bottom edge: the music bar")
            checked: AshuraSettings.edgeBottom
            onCheckedChanged: AshuraSettings.edgeBottom = checked
        }
    }
}
