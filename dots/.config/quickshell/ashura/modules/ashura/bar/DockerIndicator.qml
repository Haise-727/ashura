import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

// Bar pill: a ring filled by running/total containers with the count beside it,
// built from the same parts as the Resources pill so it reads as native.
MouseArea {
    id: root
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    visible: Docker.cliAvailable

    RowLayout {
        id: rowLayout
        spacing: 2
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        ClippedFilledCircularProgress {
            id: ring
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: Docker.total > 0 ? Docker.running / Docker.total : 0
            implicitSize: 20
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: ring.implicitSize
                height: ring.implicitSize

                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: Font.DemiBold
                    fill: 1
                    text: Docker.daemonRunning ? "deployed_code" : "deployed_code_alert"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
            text: Docker.daemonRunning ? `${Docker.running}/${Docker.total}` : Translation.tr("off")
        }
    }

    DockerPopup {
        hoverTarget: root
    }
}
