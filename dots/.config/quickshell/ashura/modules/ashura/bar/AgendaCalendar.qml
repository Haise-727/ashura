import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Ashura: the dashboard's calendar with the agenda inside it.
//
// Month view: a big month grid. A day with open items has a ring round its
// date; a day whose items are all done has a faint ring. Today is filled.
// Click a day and the month folds up to that day's week; the space it frees
// holds the day's items (tick, remove) and a field to add one. Click the day
// again, or the month name, to unfold. One motion: the rows fold and the list
// rides up with them, nothing animates on its own.
//
// Items come from services/Agenda.qml (~/.config/ashura/agenda.json), the
// same file the `ashura-agenda` command edits.
Item {
    id: cal

    property int monthShift: 0
    readonly property date today: DateTime.clock.date
    readonly property date viewing: new Date(cal.today.getFullYear(), cal.today.getMonth() + cal.monthShift, 1)
    property string selectedDate: ""           // "" = month view, else YYYY-MM-DD
    readonly property bool dayView: cal.selectedDate !== ""

    // Monday first. 42 cells, each { date: Date, inMonth: bool }.
    readonly property var cells: {
        const first = cal.viewing;
        const lead = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - lead + i);
            out.push({ date: d, inMonth: d.getMonth() === first.getMonth() });
        }
        return out;
    }
    readonly property int rowCount: cal.cells[35].inMonth ? 6 : 5
    readonly property int selectedRow: {
        if (!cal.dayView) return -1;
        for (let i = 0; i < 42; i++) if (Agenda.isoDate(cal.cells[i].date) === cal.selectedDate) return Math.floor(i / 7);
        return -1;
    }
    readonly property string todayIso: Agenda.isoDate(cal.today)

    function pick(iso) { cal.selectedDate = cal.selectedDate === iso ? "" : iso; }
    function shiftMonth(n) { cal.selectedDate = ""; cal.monthShift += n; }

    // Leaving the month (arrows, wheel) closes the day; a day of another
    // month is not shown, so it cannot stay picked.
    onSelectedRowChanged: if (cal.dayView && cal.selectedRow < 0) cal.selectedDate = ""

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => { if (!cal.dayView) cal.shiftMonth(event.angleDelta.y > 0 ? -1 : 1); }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // Header: the month (or the picked day) and the arrows.
        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: 4
            RippleButton {
                implicitHeight: 34
                implicitWidth: headText.implicitWidth + 20
                buttonRadius: 17
                colBackground: "transparent"
                // In the day view it unfolds the month; in another month it
                // comes back to this one.
                onClicked: {
                    if (cal.dayView) cal.selectedDate = "";
                    else cal.monthShift = 0;
                }
                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cal.dayView
                        text: "calendar_view_month"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        id: headText
                        anchors.verticalCenter: parent.verticalCenter
                        text: cal.dayView
                            ? Qt.formatDate(new Date(cal.selectedDate + "T12:00:00"), "dddd d MMMM")
                            : (cal.monthShift !== 0 ? "• " : "") + Qt.formatDate(cal.viewing, "MMMM yyyy")
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
            Item { Layout.fillWidth: true }
            StyledText {
                visible: !cal.dayView
                text: {
                    const p = Qt.formatDate(cal.viewing, "yyyy-MM-");
                    let n = 0;
                    for (const it of Agenda.items) if (!it.done && it.date.startsWith(p)) n++;
                    return n ? Translation.tr("%1 open").arg(n) : "";
                }
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            Repeater {
                model: [-1, 1]
                delegate: RippleButton {
                    required property int modelData
                    visible: !cal.dayView
                    implicitWidth: 30; implicitHeight: 30
                    buttonRadius: 15
                    colBackground: "transparent"
                    onClicked: cal.shiftMonth(modelData)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData < 0 ? "chevron_left" : "chevron_right"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
        }

        // Weekday names.
        Row {
            id: weekNames
            Layout.fillWidth: true
            Repeater {
                model: 7
                delegate: StyledText {
                    required property int index
                    width: grid.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((index + 1) % 7, Locale.NarrowFormat)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // The weeks. Each row folds to nothing in the day view, except the
        // picked day's week.
        Column {
            id: grid
            Layout.fillWidth: true
            // Month view: the weeks share all the height. Day view: the kept
            // week is a fixed strip and the rest goes to the items.
            readonly property real monthCellH: Math.max(36, (cal.height - 24 - header.height - weekNames.height - 3 * 6) / cal.rowCount)
            readonly property real dayCellH: 44
            Repeater {
                model: 6
                delegate: Item {
                    id: week
                    required property int index
                    readonly property bool kept: week.index < cal.rowCount && (!cal.dayView || week.index === cal.selectedRow)
                    width: grid.width
                    height: !week.kept ? 0 : cal.dayView ? grid.dayCellH : grid.monthCellH
                    opacity: week.kept ? 1 : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                    Row {
                        Repeater {
                            model: 7
                            delegate: DayCell {
                                required property int index
                                cell: cal.cells[week.index * 7 + index]
                                width: grid.width / 7
                                height: week.kept ? week.height : grid.monthCellH
                            }
                        }
                    }
                }
            }
        }

        // The picked day's items. In the month view the weeks take all the
        // room and this has none; it shows as they fold.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            clip: true
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 6
                spacing: 6
                visible: parent.height > 20
                StyledText {
                    leftPadding: 4
                    text: {
                        const n = cal.dayItems.length;
                        if (n === 0) return Translation.tr("Nothing on this day yet");
                        const open = cal.dayItems.filter(it => !it.done).length;
                        return open === n ? Translation.tr("%1 open").arg(open)
                            : open === 0 ? Translation.tr("all %1 done").arg(n)
                            : Translation.tr("%1 open, %2 done").arg(open).arg(n - open);
                    }
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: cal.dayItems
                    delegate: ItemRow {}
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 17
                    color: Appearance.colors.colLayer1
                    TextInput {
                        id: addField
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        color: Appearance.colors.colOnLayer1
                        clip: true
                        // "17:00 Submit the DA" keeps the time.
                        onAccepted: {
                            const m = text.trim().match(/^(\d{1,2}):(\d{2})\s+(.+)$/);
                            if (m) Agenda.add(cal.selectedDate, m[3], "deadline", `${m[1].padStart(2, "0")}:${m[2]}`);
                            else Agenda.add(cal.selectedDate, text);
                            text = "";
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: addField.text === ""
                            text: Translation.tr("Add an item, Enter to save (\"17:00 title\" sets a time)")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }

    // The last picked day stays in the list while the month unfolds over it.
    property string shownDate: ""
    onSelectedDateChanged: if (cal.selectedDate !== "") cal.shownDate = cal.selectedDate
    readonly property var dayItems: cal.shownDate !== "" ? Agenda.itemsOn(cal.shownDate) : []

    // One date in the grid.
    component DayCell: Item {
        id: dc
        property var cell
        readonly property string iso: Agenda.isoDate(dc.cell.date)
        readonly property bool isToday: dc.iso === cal.todayIso
        readonly property int open: Agenda.openCount[dc.iso] || 0
        readonly property int all: Agenda.allCount[dc.iso] || 0
        readonly property bool picked: dc.iso === cal.selectedDate
        readonly property real size: Math.min(width, height) - 8

        // Picked: a soft disc behind the date.
        Rectangle {
            anchors.centerIn: parent
            width: dc.size; height: dc.size; radius: dc.size / 2
            color: dc.isToday ? Appearance.colors.colPrimary
                : dc.picked ? Appearance.colors.colSecondaryContainer
                : hover.containsMouse && dc.cell.inMonth ? Appearance.colors.colLayer2Hover : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        // Items: a ring round the date (open items full, all done faint).
        Rectangle {
            anchors.centerIn: parent
            visible: dc.all > 0 && dc.cell.inMonth
            width: dc.size + (dc.isToday ? 6 : 0); height: width; radius: width / 2
            color: "transparent"
            border.width: dc.open > 0 ? 2.5 : 1.5
            border.color: dc.open > 0 ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
        }
        StyledText {
            anchors.centerIn: parent
            text: dc.cell.date.getDate()
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: dc.isToday || (dc.open > 0 && dc.cell.inMonth) ? Font.DemiBold : Font.Normal
            color: dc.isToday ? Appearance.colors.colOnPrimary
                : !dc.cell.inMonth ? Appearance.colors.colOutlineVariant
                : dc.picked ? Appearance.colors.colOnSecondaryContainer
                : Appearance.colors.colOnLayer2
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            enabled: dc.cell.inMonth
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cal.pick(dc.iso)
        }
    }

    // One agenda item: tick, title (struck when done), its time, remove.
    component ItemRow: Rectangle {
        id: ir
        required property var modelData
        width: ListView.view.width
        height: 38
        radius: 12
        color: Appearance.colors.colLayer1
        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
            spacing: 8
            RippleButton {
                implicitWidth: 28; implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                onClicked: Agenda.toggle(ir.modelData.id)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: ir.modelData.done ? "check_circle" : "radio_button_unchecked"
                    fill: ir.modelData.done ? 1 : 0
                    iconSize: 20
                    color: ir.modelData.done ? Appearance.colors.colSubtext : Appearance.colors.colPrimary
                }
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: ir.modelData.title
                font.strikeout: ir.modelData.done
                color: ir.modelData.done ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
            }
            StyledText {
                visible: (ir.modelData.time ?? "") !== ""
                text: ir.modelData.time ?? ""
                font.family: Appearance.font.family.numbers
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            RippleButton {
                implicitWidth: 28; implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                onClicked: Agenda.remove(ir.modelData.id)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 18; color: Appearance.colors.colSubtext }
                StyledToolTip { text: Translation.tr("Remove") }
            }
        }
    }
}
