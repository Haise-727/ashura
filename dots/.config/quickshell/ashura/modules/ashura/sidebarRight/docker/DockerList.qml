import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// One Docker list (containers, images or volumes), drawn like the To Do list:
// colLayer2 rounded rows with small action buttons, and the same placeholder.
//
// items are plain data with a stable `key`, so a poll that changes nothing
// keeps the same rows (no flicker, scroll and hover survive):
//   { key, header: "name" }                                   a group heading
//   { key, target, icon, iconFilled, title, subtitle,
//     actions: [{ icon, tooltip, verb, enabled }] }            a row
// A button press is reported through `triggered(target, verb)`; the list itself
// never runs anything.
Item {
    id: root
    required property var items
    signal triggered(string target, string verb)
    property string emptyPlaceholderIcon
    property string emptyPlaceholderText
    property string emptyActionText: ""      // optional button under the placeholder
    property var emptyAction: null
    property int rowSpacing: 5
    property int rowPadding: 8

    StyledListView {
        id: listView
        anchors.fill: parent
        // ScriptModel can keep a few stale delegates when its values go from many
        // to none (seen when the daemon stops), so an empty list is hidden outright
        // rather than trusted to have cleared itself.
        visible: root.items.length > 0
        spacing: root.rowSpacing
        animateAppearance: false
        model: ScriptModel {
            values: root.items
            objectProp: "key"
        }
        delegate: Item {
            id: entry
            required property var modelData
            width: ListView.view.width
            implicitHeight: modelData.header !== undefined ? headerText.implicitHeight + 8 : rowRect.implicitHeight

            StyledText {
                id: headerText
                visible: entry.modelData.header !== undefined
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                text: entry.modelData.header ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colSubtext
            }

            Rectangle {
                id: rowRect
                visible: entry.modelData.header === undefined
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: rowLayout.implicitHeight + root.rowPadding * 2
                color: Appearance.colors.colLayer2
                radius: Appearance.rounding.small

                RowLayout {
                    id: rowLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 8

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: entry.modelData.icon ?? ""
                        fill: entry.modelData.iconFilled ? 1 : 0
                        iconSize: Appearance.font.pixelSize.larger
                        color: entry.modelData.iconFilled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: entry.modelData.title ?? ""
                            elide: Text.ElideMiddle
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: (entry.modelData.subtitle ?? "").length > 0
                            text: entry.modelData.subtitle ?? ""
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }

                    Repeater {
                        model: entry.modelData.actions ?? []
                        delegate: DockerActionButton {
                            required property var modelData
                            Layout.fillWidth: false
                            Layout.alignment: Qt.AlignVCenter
                            enabled: modelData.enabled ?? true
                            opacity: enabled ? 1 : 0.4
                            tooltipText: modelData.tooltip ?? ""
                            onClicked: root.triggered(entry.modelData.target, modelData.verb)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.icon
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        // Placeholder when the list is empty (same as the To Do list's)
        visible: opacity > 0
        opacity: root.items.length === 0 ? 1 : 0
        anchors.fill: parent
        Behavior on opacity {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 55
                color: Appearance.m3colors.m3outline
                text: root.emptyPlaceholderIcon
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3outline
                horizontalAlignment: Text.AlignHCenter
                text: root.emptyPlaceholderText
            }
            RippleButton {
                visible: root.emptyActionText.length > 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                implicitHeight: 34
                implicitWidth: emptyActionLabel.implicitWidth + 28
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                onClicked: if (root.emptyAction) root.emptyAction()
                contentItem: StyledText {
                    id: emptyActionLabel
                    anchors.centerIn: parent
                    text: root.emptyActionText
                    color: Appearance.colors.colOnLayer2
                }
            }
        }
    }
}
