import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Ashura: an on-screen keyboard inside the lock screen, for when the laptop's
// keyboard misbehaves (its matrix has a thermal fault). Nothing can draw above a
// session lock, so the desktop OSK (a separate layer that injects keys) cannot help
// here. This one edits the password text directly: no key injection, nothing
// leaves the lock surface.
//
//   typed(text)   a character was pressed
//   backspace()
//   submit()      the enter key
Rectangle {
    id: root
    signal typed(string text)
    signal backspace()
    signal submit()

    property bool shifted: false
    property bool symbols: false

    readonly property var letterRows: [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]
    readonly property var symbolRows: [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["@", "#", "$", "%", "&", "*", "-", "+", "(", ")"],
        ["!", "\"", "'", ":", ";", "/", "?", ",", ".", "_"]
    ]
    readonly property var rows: symbols ? symbolRows : letterRows
    readonly property int keySize: 46

    implicitWidth: keysColumn.implicitWidth + 24
    implicitHeight: keysColumn.implicitHeight + 24
    radius: Appearance.rounding.large
    color: Appearance.colors.colLayer0
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    component Key: RippleButton {
        id: key
        property string label
        property string glyph: ""
        property real units: 1
        implicitWidth: root.keySize * units + (units - 1) * 6
        implicitHeight: root.keySize
        buttonRadius: Appearance.rounding.small
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        contentItem: Item {
            MaterialSymbol {
                anchors.centerIn: parent
                visible: key.glyph !== ""
                text: key.glyph
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer2
            }
            StyledText {
                anchors.centerIn: parent
                visible: key.glyph === ""
                text: key.label
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer2
            }
        }
    }

    ColumnLayout {
        id: keysColumn
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.rows
            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Key {    // shift sits left of the last letter row
                    visible: index === 2 && !root.symbols
                    glyph: root.shifted ? "keyboard_capslock_badge" : "shift"
                    units: 1.5
                    toggled: root.shifted
                    onClicked: root.shifted = !root.shifted
                }
                Repeater {
                    model: modelData
                    delegate: Key {
                        required property string modelData
                        label: root.shifted && !root.symbols ? modelData.toUpperCase() : modelData
                        onClicked: root.typed(label)
                    }
                }
                Key {
                    visible: index === 2
                    glyph: "backspace"
                    units: 1.5
                    onClicked: root.backspace()
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Key {
                label: root.symbols ? "abc" : "?123"
                units: 1.5
                onClicked: root.symbols = !root.symbols
            }
            Key {
                label: " "
                glyph: "space_bar"
                units: 5
                onClicked: root.typed(" ")
            }
            Key {
                glyph: "keyboard_return"
                units: 2
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                onClicked: root.submit()
            }
        }
    }
}
