import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Ashura: the music visuals (services/AshuraSettings, ~/.config/ashura/settings.json).
ContentPage {
    forceWidth: true

    ContentSection {
        icon: "graphic_eq"
        title: Translation.tr("While music plays")

        ConfigSwitch {
            buttonIcon: "border_outer"
            text: Translation.tr("Wave round the focused window (two or more windows open)")
            checked: AshuraSettings.waveBorder
            onCheckedChanged: AshuraSettings.waveBorder = checked
        }
        ConfigSwitch {
            buttonIcon: "equalizer"
            text: Translation.tr("Visualizer along the bottom edge")
            checked: AshuraSettings.edgeVisualizer
            onCheckedChanged: AshuraSettings.edgeVisualizer = checked
        }
        ConfigSwitch {
            buttonIcon: "layers_clear"
            text: Translation.tr("Hide the bottom visualizer when two or more windows are open (the wave shows then)")
            checked: AshuraSettings.edgeVisualizerHideWithWindows
            onCheckedChanged: AshuraSettings.edgeVisualizerHideWithWindows = checked
        }
    }
}
