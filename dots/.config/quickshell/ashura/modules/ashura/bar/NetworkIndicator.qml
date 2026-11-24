import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Ashura: the bar's network icon with its traffic (panel style X9, reworked).
// Beside the icon, stacked chevrons slide down while downloading and up while
// uploading, faster the more data moves; quiet traffic shows nothing.
// Hover for both speeds. Speeds come from the byte counters in /proc/net/dev
// (every interface but loopback), read once a second.
MouseArea {
    id: root
    property color color: Appearance.colors.colOnLayer1
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property real quietBps: 16 * 1024        // below this a direction is idle
    property real rxBps: 0
    property real txBps: 0
    property real lastRx: -1
    property real lastTx: -1
    property real lastAt: 0

    FileView { id: netDev; path: "/proc/net/dev"; blockLoading: true }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            netDev.reload();
            let rx = 0, tx = 0;
            for (const line of netDev.text().split("\n").slice(2)) {
                const m = line.trim().match(/^([^:]+):\s*(.*)$/);
                if (!m || m[1] === "lo") continue;
                const f = m[2].split(/\s+/);
                rx += Number(f[0]) || 0;
                tx += Number(f[8]) || 0;
            }
            const now = Date.now();
            if (root.lastRx >= 0) {
                const dt = Math.max(0.2, (now - root.lastAt) / 1000);
                root.rxBps = Math.max(0, (rx - root.lastRx) / dt);
                root.txBps = Math.max(0, (tx - root.lastTx) / dt);
            }
            root.lastRx = rx; root.lastTx = tx; root.lastAt = now;
        }
    }

    function rate(bps) {
        const u = ["B/s", "KB/s", "MB/s", "GB/s"];
        let i = 0;
        while (bps >= 1024 && i < u.length - 1) { bps /= 1024; i++; }
        return `${bps.toFixed(bps < 10 && i > 0 ? 1 : 0)} ${u[i]}`;
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 1
        Chevrons { down: true; bps: root.rxBps }
        Chevrons { down: false; bps: root.txBps }
        MaterialSymbol {
            text: Network.materialSymbol
            iconSize: Appearance.font.pixelSize.larger
            color: root.color
        }
    }

    // A thin column of two chevrons sliding one way, on a loop. The loop
    // shortens as the speed grows (log scale: 16 KB/s slow, ~50 MB/s fast).
    component Chevrons: Item {
        id: ch
        required property bool down
        required property real bps
        readonly property bool active: ch.bps >= root.quietBps
        readonly property int period: {
            const k = Math.log10(Math.max(1, ch.bps / root.quietBps)) / Math.log10(3000);
            return Math.round(1100 - 800 * Math.max(0, Math.min(1, k)));
        }
        readonly property real step: 8
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: ch.active ? 9 : 0
        implicitHeight: 20
        visible: ch.active
        clip: true
        property real offset: 0
        NumberAnimation on offset {
            id: loop
            running: ch.active
            from: 0; to: ch.step
            duration: ch.period
            loops: Animation.Infinite
        }
        // A new speed takes effect on the next pass, so the loop never jumps.
        onPeriodChanged: if (loop.running) loop.restart()
        Repeater {
            model: 4
            delegate: MaterialSymbol {
                required property int index
                anchors.horizontalCenter: parent.horizontalCenter
                text: ch.down ? "keyboard_arrow_down" : "keyboard_arrow_up"
                iconSize: 13
                fill: 1
                color: root.color
                // Spaced one step apart; the whole stack moves by one step per
                // loop, so it reads as an endless flow.
                y: ch.down ? (index - 2) * ch.step + ch.offset + 2
                           : (index - 1) * ch.step - ch.offset + 2
                // Fade towards the ends of the column.
                opacity: {
                    const mid = (y + height / 2) / ch.height;
                    return Math.max(0, 1 - Math.abs(mid - 0.5) * 2.2);
                }
            }
        }
    }

    StyledPopup {
        hoverTarget: root
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            StyledPopupHeaderRow {
                icon: Network.materialSymbol
                label: Network.networkName !== "" ? Network.networkName : Translation.tr("Network")
            }
            StyledPopupValueRow {
                icon: "download"
                label: Translation.tr("Down")
                value: root.rate(root.rxBps)
            }
            StyledPopupValueRow {
                icon: "upload"
                label: Translation.tr("Up")
                value: root.rate(root.txBps)
            }
        }
    }
}
