import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ashura.sidebarRight.volumeMixer
import QtQuick
import QtQuick.Layouts

// Ashura: hover the bar's volume icon for the per-app mixer (caelestia keeps its
// audio popout on the bar the same way). The master slider on top, then the shell's
// mixer list and output picker.
HoverPanel {
    id: root
    namespace: "quickshell:mixerPanel"
    contentWidth: 380
    contentHeight: 420

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            RippleButton {
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: 18
                onClicked: Audio.toggleMute()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: (Audio.sink?.audio.muted ?? false) ? "volume_off" : "volume_up"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                }
            }
            StyledSlider {
                Layout.fillWidth: true
                from: 0
                to: Audio.maxVolume
                value: Audio.sink?.audio.volume ?? 0
                tooltipContent: `${Math.round(value * 100)}%`
                onMoved: if (Audio.sink) Audio.sink.audio.volume = value
            }
            StyledText {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: `${Math.round((Audio.sink?.audio.volume ?? 0) * 100)}%`
                color: Appearance.colors.colOnLayer1
            }
        }

        VolumeDialogContent {
            Layout.fillWidth: true
            Layout.fillHeight: true
            isSink: true
        }
    }
}
