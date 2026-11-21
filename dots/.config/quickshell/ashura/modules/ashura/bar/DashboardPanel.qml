import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ashura.sidebarRight.calendar
import qs.modules.ashura.sidebarRight.apps
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Qt5Compat.GraphicalEffects

// Ashura dashboard: hover the top edge (middle half) and it drops out of the
// bar, caelestia-style,
// with three tabs. Layout of the first tab follows caelestia's dashboard
// (GPL-3.0, github.com/caelestia-dots/shell), minus weather:
//
//   Dashboard    you, the date, the calendar, CPU/RAM/swap bars, the player
//   Performance  CPU/RAM/swap graphs, power profile, per-app usage
//   Cockpits     devpit's repos: open, show/hide, close fully
HoverPanel {
    id: root
    namespace: "quickshell:dashboard"
    centerOnScreen: true
    // Hangs from the bar; hover the middle half of the very top edge of the
    // screen to open it. Leaving it closes it at once (the short grace only
    // covers the hand-over from the edge strip to the panel).
    attached: true
    triggerFraction: 0.5
    graceMs: 100
    contentWidth: 900
    contentHeight: 540

    property int tab: 0
    FileView { id: hostFile; path: "/etc/hostname" }

    // CPU/GPU/disks/network for the Performance tab (scripts/ashura/sysstats.py),
    // polled every 2 s only while that tab is open.
    property var stats: ({})
    property real rxRate: 0
    property real txRate: 0
    property real rxStart: -1
    property real txStart: -1
    property int diskIndex: 0
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root.shown && root.tab === 1
        onTriggered: if (!statsProc.running) statsProc.running = true
    }
    Process {
        id: statsProc
        command: ["python3", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/ashura/sysstats.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                let s;
                try { s = JSON.parse(text); } catch (e) { return; }
                if (root.stats.rx !== undefined) {
                    root.rxRate = Math.max(0, (s.rx - root.stats.rx) / 2);
                    root.txRate = Math.max(0, (s.tx - root.stats.tx) / 2);
                }
                if (root.rxStart < 0) { root.rxStart = s.rx; root.txStart = s.tx; }
                root.stats = s;
            }
        }
    }
    function bytes(n) {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
        return `${n.toFixed(n < 10 && i > 0 ? 1 : 0)} ${u[i]}`;
    }
    onShownChanged: if (shown && tab === 3) Cockpit.refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        SecondaryTabBar {
            id: tabBar
            Layout.fillWidth: true
            currentIndex: root.tab
            onCurrentIndexChanged: {
                root.tab = currentIndex;
                if (currentIndex === 3) Cockpit.refresh();
            }
            Repeater {
                model: [
                    { name: Translation.tr("Dashboard"), icon: "dashboard" },
                    { name: Translation.tr("Performance"), icon: "speed" },
                    { name: Translation.tr("Apps"), icon: "apps" },
                    { name: Translation.tr("Cockpits"), icon: "rocket_launch" }
                ]
                delegate: SecondaryTabButton {
                    required property var modelData
                    buttonText: modelData.name
                    buttonIcon: modelData.icon
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tab

            DashTab {}
            PerformanceTab {}
            AppsTab {}
            CockpitsTab {}
        }
    }

    // ------------------------------------------------------------ shared bits
    component Card: Rectangle {
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer2
    }
    component Label: StyledText {
        color: Appearance.colors.colOnLayer2
    }
    component SubLabel: StyledText {
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.smaller
    }

    // ------------------------------------------------------------ Dashboard
    component DashTab: GridLayout {
        columns: 4
        rowSpacing: 10
        columnSpacing: 10

        // You
        // A gif beside you (Haise will pick one; kurukuru until then). The
        // battery lives in the Performance tab.
        Card {
            Layout.row: 0
            Layout.column: 2
            Layout.preferredWidth: 120
            Layout.preferredHeight: 104
            clip: true
            AnimatedImage {
                anchors.fill: parent
                anchors.margins: 6
                fillMode: Image.PreserveAspectFit
                // Settings, Dashboard: any gif; empty means the bundled one.
                source: AshuraSettings.dashboardGif !== "" ? `file://${AshuraSettings.dashboardGif}` : Quickshell.shellPath("assets/ashura/dashboard.gif")
                playing: root.shown && root.tab === 0
            }
        }

        Card {
            Layout.row: 0
            Layout.column: 0
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                Rectangle {
                    width: 76
                    height: 76
                    radius: 38
                    color: Appearance.colors.colSecondaryContainer
                    clip: true
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: "person"
                        iconSize: 40
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    Image {
                        id: face
                        anchors.fill: parent
                        source: `file://${Directories.home.replace("file://", "")}/.face`
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        cache: false
                    }
                    OpacityMask {
                        anchors.fill: parent
                        visible: face.status === Image.Ready
                        source: face
                        maskSource: Rectangle { width: 76; height: 76; radius: 38 }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Label {
                        text: `${SystemInfo.username}@${hostFile.text().trim() || "arch"}`
                        font.pixelSize: Appearance.font.pixelSize.huge
                    }
                    RowLayout {
                        spacing: 6
                        MaterialSymbol { text: "deployed_code"; color: Appearance.colors.colPrimary; iconSize: Appearance.font.pixelSize.normal }
                        SubLabel { text: `${SystemInfo.distroName} · Hyprland` }
                    }
                    RowLayout {
                        spacing: 6
                        MaterialSymbol { text: "timer"; color: Appearance.colors.colPrimary; iconSize: Appearance.font.pixelSize.normal }
                        SubLabel { text: Translation.tr("up %1").arg(DateTime.uptime) }
                    }
                }
            }
        }

        // The player, the full height on the right
        Card {
            Layout.row: 0
            Layout.column: 3
            Layout.rowSpan: 2
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            MiniPlayer { anchors.fill: parent; anchors.margins: 14 }
        }

        // The date, stacked
        Card {
            Layout.row: 1
            Layout.column: 0
            Layout.preferredWidth: 104
            Layout.fillHeight: true
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(DateTime.clock.date, "hh")
                    font.pixelSize: 40
                    font.family: Appearance.font.family.numbers
                    color: Appearance.colors.colPrimary
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "•••"
                    color: Appearance.colors.colPrimary
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(DateTime.clock.date, "mm")
                    font.pixelSize: 40
                    font.family: Appearance.font.family.numbers
                    color: Appearance.colors.colPrimary
                }
                SubLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(DateTime.clock.date, "ddd, d")
                }
            }
        }

        // The calendar
        Card {
            Layout.row: 1
            Layout.column: 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            CalendarWidget {
                anchors.fill: parent
                anchors.margins: 6
            }
        }

        // CPU / RAM / swap as three bars
        Card {
            Layout.row: 1
            Layout.column: 2
            Layout.preferredWidth: 120
            Layout.fillHeight: true
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14
                Repeater {
                    model: [
                        { icon: "planner_review", value: ResourceUsage.cpuUsage },
                        { icon: "memory", value: ResourceUsage.memoryUsedPercentage },
                        { icon: "swap_horiz", value: ResourceUsage.swapUsedPercentage }
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillHeight: true
                        spacing: 6
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillHeight: true
                            implicitWidth: 10
                            radius: 5
                            color: Appearance.colors.colSecondaryContainer
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                radius: parent.radius
                                height: Math.max(width, parent.height * Math.min(1, modelData.value))
                                color: Appearance.colors.colPrimary
                                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }

    component MiniPlayer: ColumnLayout {
        readonly property MprisPlayer player: MprisController.activePlayer
        spacing: 8
        Item {   // the cover inside a ring of bars (CoverRing)
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 180
            Layout.preferredHeight: 180
            CoverRing {
                anchors.centerIn: parent
                innerRadius: 69
                maxLength: 20
                active: root.shown && root.tab === 0 && (MprisController.activePlayer?.isPlaying ?? false)
            }
        Rectangle {
            anchors.centerIn: parent
            width: 130
            height: 130
            radius: 65
            color: Appearance.colors.colSecondaryContainer
            clip: true
            MaterialSymbol {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: "music_note"
                iconSize: 48
                color: Appearance.colors.colOnSecondaryContainer
            }
            Image {
                id: cover
                anchors.fill: parent
                source: MprisController.activePlayer?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            OpacityMask {
                anchors.fill: parent
                visible: cover.status === Image.Ready
                source: cover
                maskSource: Rectangle { width: 130; height: 130; radius: 65 }
            }
        }
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: StringUtils.cleanMusicTitle(parent.player?.trackTitle) || Translation.tr("Nothing playing")
        }
        SubLabel {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: parent.player?.trackArtist ?? ""
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Repeater {
                model: [
                    { icon: "skip_previous", act: () => MprisController.activePlayer?.previous() },
                    { icon: (MprisController.activePlayer?.isPlaying ?? false) ? "pause" : "play_arrow", act: () => MprisController.activePlayer?.togglePlaying() },
                    { icon: "skip_next", act: () => MprisController.activePlayer?.next() }
                ]
                delegate: RippleButton {
                    required property var modelData
                    implicitWidth: 38
                    implicitHeight: 38
                    buttonRadius: 19
                    enabled: MprisController.activePlayer !== null
                    onClicked: modelData.act()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData.icon
                        fill: 1
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
        }
        // The bongo cat (caelestia's), drumming only while music plays.
        AnimatedImage {
            visible: AshuraSettings.dashboardBongoCat
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 180
            Layout.preferredHeight: 116
            fillMode: Image.PreserveAspectFit
            source: Quickshell.shellPath("assets/ashura/bongocat.gif")
            playing: root.shown && (MprisController.activePlayer?.isPlaying ?? false)
        }
        Item { Layout.fillHeight: true }
    }

    // ------------------------------------------------------------ Performance
    // After caelestia's Performance tab: numbers and rings, no graphs.
    // The battery as a battery: its outline fills to the charge level, with a
    // bolt in the middle while the charger is in. "Plugged in" covers a full
    // battery or one held below 100% by the charge limit (UPower then reports
    // "fully charged" or "pending", not "charging").
    component BatteryBlock: ColumnLayout {
        id: batt
        readonly property bool onAc: !UPower.onBattery
        readonly property real level: Battery.percentage
        readonly property color fill: Battery.isLowAndNotCharging ? Appearance.colors.colError : Appearance.colors.colPrimary
        spacing: 6
        SubLabel {
            text: Battery.isCharging ? Translation.tr("Charging") : batt.onAc ? Translation.tr("Plugged in") : Translation.tr("On battery")
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: 3
            Rectangle {   // the body
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: 14
                color: "transparent"
                border.width: 2
                border.color: Appearance.colors.colOutlineVariant
                Rectangle {   // the charge
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 5 }
                    width: Math.max(radius * 2, (parent.width - 10) * batt.level)
                    radius: 9
                    color: batt.fill
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: batt.onAc
                    text: "bolt"
                    fill: 1
                    iconSize: 30
                    // Readable on both the fill and the empty part.
                    color: batt.level > 0.55 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                }
            }
            Rectangle {   // the terminal nub
                Layout.preferredWidth: 5
                Layout.preferredHeight: 20
                radius: 2
                color: Appearance.colors.colOutlineVariant
            }
        }
        Label {
            text: `${Math.round(batt.level * 100)}%`
            font.pixelSize: 30
            font.family: Appearance.font.family.numbers
            color: Battery.isLowAndNotCharging ? Appearance.colors.colError : Appearance.colors.colOnLayer2
        }
        SubLabel {
            readonly property real secs: Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty
            visible: secs > 0 && (Battery.isCharging || !batt.onAc)
            text: `${Math.floor(secs / 3600)}h ${Math.floor(secs % 3600 / 60)}m ${Battery.isCharging ? Translation.tr("to full") : Translation.tr("left")}`
        }
    }

    component Ring: Item {
        id: ring
        property real value: 0
        property string label: ""
        implicitWidth: 104
        implicitHeight: 104
        CircularProgress {
            anchors.centerIn: parent
            implicitSize: 100
            lineWidth: 8
            value: ring.value
            colPrimary: Appearance.colors.colPrimary
            colSecondary: Appearance.colors.colSecondaryContainer
        }
        Column {
            anchors.centerIn: parent
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: `${Math.round(ring.value * 100)}%`; font.pixelSize: 22; font.family: Appearance.font.family.numbers }
            SubLabel { anchors.horizontalCenter: parent.horizontalCenter; text: ring.label }
        }
    }

    component ChipCard: Card {
        id: chip
        property string icon
        property string title
        property string detail
        property real usage: 0
        property int temp: -1
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    spacing: 6
                    MaterialSymbol { text: chip.icon; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colPrimary }
                    Label { text: chip.title; font.pixelSize: Appearance.font.pixelSize.large }
                }
                SubLabel { Layout.fillWidth: true; elide: Text.ElideRight; text: chip.detail }
                Item { Layout.fillHeight: true }
                RowLayout {
                    spacing: 6
                    MaterialSymbol { text: "thermostat"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext }
                    SubLabel { text: chip.temp >= 0 ? `${chip.temp}°C` : "--" }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Appearance.colors.colSecondaryContainer
                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, (chip.temp - 30) / 70))
                        height: parent.height
                        radius: 3
                        color: chip.temp >= 85 ? Appearance.colors.colError : Appearance.colors.colPrimary
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                }
            }
            Rectangle {
                Layout.preferredWidth: 78
                Layout.preferredHeight: 78
                radius: Appearance.rounding.normal
                color: Appearance.colors.colSecondaryContainer
                Column {
                    anchors.centerIn: parent
                    SubLabel { anchors.horizontalCenter: parent.horizontalCenter; text: Translation.tr("Usage") }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${Math.round(chip.usage * 100)}%`
                        font.pixelSize: 24
                        font.family: Appearance.font.family.numbers
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }
    }

    component PerformanceTab: GridLayout {
        columns: 3
        rowSpacing: 10
        columnSpacing: 10

        ChipCard {
            Layout.row: 0; Layout.column: 0
            Layout.fillWidth: true; Layout.fillHeight: true
            icon: "memory_alt"; title: Translation.tr("CPU")
            detail: root.stats.cpu ?? ""
            usage: ResourceUsage.cpuUsage
            temp: root.stats.cpuTemp ?? -1
        }
        ChipCard {
            Layout.row: 0; Layout.column: 1
            Layout.fillWidth: true; Layout.fillHeight: true
            icon: "developer_board"; title: Translation.tr("GPU")
            detail: root.stats.gpu ?? ""
            usage: root.stats.gpuUsage ?? 0
            temp: root.stats.gpuTemp ?? -1
        }
        // Battery, tall, with the power profile under it
        Card {
            Layout.row: 0; Layout.column: 2; Layout.rowSpan: 2
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                BatteryBlock { Layout.fillWidth: true; Layout.fillHeight: true }
                SubLabel { text: Translation.tr("Power profile") }
                Repeater {
                    model: [
                        { profile: PowerProfile.PowerSaver, name: Translation.tr("Saver"), icon: "energy_savings_leaf" },
                        { profile: PowerProfile.Balanced, name: Translation.tr("Balanced"), icon: "airwave" },
                        { profile: PowerProfile.Performance, name: Translation.tr("Performance"), icon: "local_fire_department" }
                    ]
                    delegate: RippleButton {
                        required property var modelData
                        readonly property bool active: PowerProfiles.profile === modelData.profile
                        visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                        Layout.fillWidth: true
                        implicitHeight: 34
                        buttonRadius: 17
                        toggled: active
                        colBackgroundToggled: Appearance.colors.colPrimary
                        onClicked: PowerProfiles.profile = modelData.profile
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol { text: modelData.icon; iconSize: Appearance.font.pixelSize.larger
                                color: active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2 }
                            StyledText { text: modelData.name; color: active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2 }
                        }
                    }
                }
            }
        }

        // Second row: storage, network, memory
        RowLayout {
            Layout.row: 1; Layout.column: 0; Layout.columnSpan: 2
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 10

            Card {   // Storage: your real partitions, not swap
                id: storageCard
                Layout.fillWidth: true; Layout.fillHeight: true
                readonly property var disks: root.stats.disks ?? []
                readonly property var disk: disks[Math.min(root.diskIndex, Math.max(0, disks.length - 1))] ?? null
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    Ring { value: storageCard.disk ? storageCard.disk.used / storageCard.disk.total : 0; label: Translation.tr("used") }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label { text: Translation.tr("Storage"); font.pixelSize: Appearance.font.pixelSize.large }
                        SubLabel {
                            text: storageCard.disk ? `${root.bytes(storageCard.disk.used)} / ${root.bytes(storageCard.disk.total)}` : "--"
                        }
                        SubLabel {   // what is left on the selected disk
                            text: storageCard.disk ? Translation.tr("%1 free").arg(root.bytes(storageCard.disk.total - storageCard.disk.used)) : ""
                            color: Appearance.colors.colPrimary
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: storageCard.disks
                                delegate: RippleButton {
                                    required property var modelData
                                    required property int index
                                    implicitHeight: 26
                                    implicitWidth: diskName.implicitWidth + 18
                                    buttonRadius: 13
                                    toggled: root.diskIndex === index
                                    colBackgroundToggled: Appearance.colors.colPrimary
                                    onClicked: root.diskIndex = index
                                    contentItem: StyledText {
                                        id: diskName
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Card {   // Network
                Layout.preferredWidth: 220; Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6
                    RowLayout {
                        spacing: 6
                        MaterialSymbol { text: "swap_vert"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colPrimary }
                        Label { text: Translation.tr("Network"); font.pixelSize: Appearance.font.pixelSize.large }
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout { SubLabel { text: Translation.tr("Download"); Layout.fillWidth: true } Label { text: `${root.bytes(root.rxRate)}/s` } }
                    RowLayout { SubLabel { text: Translation.tr("Upload"); Layout.fillWidth: true } Label { text: `${root.bytes(root.txRate)}/s` } }
                    RowLayout {
                        SubLabel { text: Translation.tr("Total"); Layout.fillWidth: true }
                        SubLabel { text: root.rxStart >= 0 ? `↓${root.bytes(root.stats.rx - root.rxStart)} ↑${root.bytes(root.stats.tx - root.txStart)}` : "--" }
                    }
                }
            }

            Card {   // Memory
                Layout.preferredWidth: 150; Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    Label { Layout.alignment: Qt.AlignHCenter; text: Translation.tr("Memory"); font.pixelSize: Appearance.font.pixelSize.large }
                    Ring { Layout.alignment: Qt.AlignHCenter; value: ResourceUsage.memoryUsedPercentage; label: Translation.tr("used") }
                    SubLabel {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${(ResourceUsage.memoryUsed / 1048576).toFixed(1)} / ${(ResourceUsage.memoryTotal / 1048576).toFixed(1)} GB`
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ Apps
    // Per-app CPU and memory (PSS), Windows task-manager style; polls only while open.
    component AppsTab: Card {
        Loader {
            anchors.fill: parent
            anchors.margins: 8
            active: root.shown && root.tab === 2
            sourceComponent: AppsWidget {}
        }
    }

    // ------------------------------------------------------------ Cockpits
    component CockpitsTab: ColumnLayout {
        spacing: 10

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                MaterialSymbol { text: "rocket_launch"; fill: Cockpit.visible ? 1 : 0; color: Appearance.colors.colPrimary; iconSize: Appearance.font.pixelSize.huge }
                Label {
                    text: Cockpit.current ? Translation.tr("On stage: %1").arg(Cockpit.currentName) : Translation.tr("No repo on stage")
                }
                SubLabel { text: Translation.tr("Super+D in/out · Super+Space picks · Ctrl+Super+D closes") }
                Item { Layout.fillWidth: true }
                RippleButton {
                    implicitHeight: 36
                    implicitWidth: pickRow.implicitWidth + 24
                    buttonRadius: 18
                    colBackground: Appearance.colors.colSecondaryContainer
                    onClicked: { root.pinned = false; Cockpit.openPicker(); }
                    contentItem: RowLayout {
                        id: pickRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol { text: "add"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                        StyledText { text: Translation.tr("Pick or add"); color: Appearance.colors.colOnSecondaryContainer }
                    }
                }
            }
        }

        StyledListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: Cockpit.cockpits
            delegate: Card {
                id: row
                required property var modelData
                readonly property bool onStage: Cockpit.current === modelData.id
                readonly property int windows: Cockpit.repos[modelData.id]?.windows ?? 0
                width: ListView.view.width
                height: 56
                color: onStage ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                MaterialSymbol {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.onStage ? "rocket_launch" : "folder"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }
                Column {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: 12
                    anchors.right: rowButtons.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Label { width: parent.width; elide: Text.ElideRight; text: row.modelData.name }
                    SubLabel {
                        width: parent.width
                        elide: Text.ElideRight
                        text: {
                            const g = row.modelData.git ?? {};
                            const bits = [g.branch ?? ""];
                            if (g.dirty) bits.push(`${g.dirty} changed`);
                            if (g.ahead) bits.push(`${g.ahead} unpushed`);
                            bits.push(row.windows ? `${row.windows} window${row.windows > 1 ? "s" : ""}` : "closed");
                            return bits.filter(b => b).join(" · ");
                        }
                    }
                }
                Row {
                    id: rowButtons
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    RippleButton {
                        implicitWidth: 36; implicitHeight: 36; buttonRadius: 18
                        onClicked: { root.pinned = false; row.onStage ? Cockpit.toggle() : Cockpit.open(row.modelData.id); }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: row.onStage ? "swap_horiz" : "play_arrow"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer2 }
                        StyledToolTip { text: row.onStage ? Translation.tr("Go in / out") : Translation.tr("Open in the cockpit") }
                    }
                    RippleButton {
                        visible: row.windows > 0
                        implicitWidth: 36; implicitHeight: 36; buttonRadius: 18
                        onClicked: Cockpit.close(row.modelData.id)
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer2 }
                        StyledToolTip { text: Translation.tr("Close this repo's windows") }
                    }
                }
            }
            PagePlaceholder {
                shown: Cockpit.cockpits.length === 0
                icon: "rocket_launch"
                title: Translation.tr("No cockpits yet")
                description: Translation.tr("Super+Space, then pick a repo to add")
            }
        }
    }
}
