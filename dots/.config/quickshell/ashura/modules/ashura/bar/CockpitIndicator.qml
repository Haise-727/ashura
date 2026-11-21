import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

// Bar entry for the Ashura cockpit. With no repo chosen it is just the icon and a
// click opens the picker; with a repo it shows the name, and a click shows or hides
// the cockpit. The icon is filled while the repo is on stage. Built from the same
// parts as the Resources and Docker pills.
MouseArea {
    id: root
    readonly property bool hasRepo: Cockpit.current !== ""
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.hasRepo ? Cockpit.toggle() : Cockpit.openPicker()

    RowLayout {
        id: rowLayout
        spacing: 3
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: "rocket_launch"
            fill: Cockpit.visible ? 1 : 0
            iconSize: Appearance.font.pixelSize.large
            color: Cockpit.visible ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
        }

        StyledText {
            visible: root.hasRepo
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 120
            elide: Text.ElideRight
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
            text: Cockpit.currentName
        }
    }
}
