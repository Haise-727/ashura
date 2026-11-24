import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Ashura: pips beside the bar clock, one per open Agenda item that is
// overdue or due in the next two days (at most five, then "+n").
//   red        overdue
//   accent     due within a day
//   faint      due within two days
// Hovering them shows the nearest few with a countdown. An item without a
// time is due at the end of its day. Hidden when nothing is due soon.
MouseArea {
    id: root
    hoverEnabled: true
    acceptedButtons: Qt.NoButton          // a click still pins the dashboard
    implicitWidth: visible ? pipRow.implicitWidth + 6 : 0
    implicitHeight: Appearance.sizes.barHeight
    visible: root.soon.length > 0

    readonly property int windowHours: 48
    property date now: new Date()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = new Date() }

    function dueOf(it) { return new Date(`${it.date}T${it.time || "23:59"}:00`); }

    // Open items overdue or due within the window, nearest first, each with
    // its due date and the minutes left (negative when overdue).
    readonly property var soon: {
        const limit = root.now.getTime() + root.windowHours * 3600000;
        const out = [];
        for (const it of Agenda.items) {
            if (it.done) continue;
            const due = root.dueOf(it);
            if (due.getTime() > limit) continue;
            out.push({ title: it.title, due: due, mins: Math.round((due.getTime() - root.now.getTime()) / 60000) });
        }
        out.sort((a, b) => a.due - b.due);
        return out;
    }

    function countdown(mins) {
        const a = Math.abs(mins);
        const d = Math.floor(a / 1440), h = Math.floor((a % 1440) / 60), m = a % 60;
        const s = d > 0 ? `${d} d ${h} h` : h > 0 ? `${h} h ${m} min` : `${m} min`;
        return mins < 0 ? Translation.tr("%1 overdue").arg(s) : Translation.tr("in %1").arg(s);
    }

    Row {
        id: pipRow
        anchors.centerIn: parent
        spacing: 3
        Repeater {
            model: Math.min(5, root.soon.length)
            delegate: Rectangle {
                required property int index
                readonly property int mins: root.soon[index].mins
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: mins < 0 ? Appearance.colors.colError
                    : mins <= 1440 ? Appearance.colors.colPrimary
                    : Appearance.colors.colOutline
            }
        }
        StyledText {
            visible: root.soon.length > 5
            anchors.verticalCenter: parent.verticalCenter
            text: `+${root.soon.length - 5}`
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }
    }

    StyledPopup {
        hoverTarget: root
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            StyledPopupHeaderRow {
                icon: "event_upcoming"
                label: Translation.tr("Due soon")
            }
            Repeater {
                model: Math.min(4, root.soon.length)
                delegate: RowLayout {
                    required property int index
                    readonly property var entry: root.soon[index]
                    Layout.fillWidth: true
                    spacing: 6
                    MaterialSymbol {
                        text: entry.mins < 0 ? "warning" : "schedule"
                        iconSize: Appearance.font.pixelSize.large
                        color: entry.mins < 0 ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 220
                        elide: Text.ElideRight
                        text: entry.title
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        Layout.leftMargin: 18
                        Layout.alignment: Qt.AlignRight
                        text: root.countdown(entry.mins)
                        font.family: Appearance.font.family.numbers
                        color: entry.mins < 0 ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
            StyledText {
                visible: root.soon.length > 4
                text: Translation.tr("and %1 more in the calendar").arg(root.soon.length - 4)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
}
