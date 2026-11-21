import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property int marks: 0          // Ashura: open Agenda items on this day
    property bool selected: false  // Ashura: the day the dashboard shows items for

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38; 
    implicitHeight: 38;

    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small
    
    contentItem: StyledText {
        anchors.fill: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: (isToday == 1) ? Appearance.m3colors.m3onPrimary : 
            (isToday == 0) ? Appearance.colors.colOnLayer1 : 
            Appearance.colors.colOutlineVariant

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
    // A ring round the selected day, a dot under a day with items.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: button.buttonRadius
        color: "transparent"
        border.width: 1.5
        border.color: Appearance.colors.colPrimary
        visible: button.selected && button.isToday != 1
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        width: 5; height: 5; radius: 2.5
        visible: button.marks > 0
        color: button.isToday == 1 ? Appearance.m3colors.m3onPrimary : Appearance.colors.colPrimary
    }
}

