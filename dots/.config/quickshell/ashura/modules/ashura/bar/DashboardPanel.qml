import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ashura.sidebarRight.apps
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Qt5Compat.GraphicalEffects

// Ashura dashboard: hover the top edge (middle half) and it drops out of the
// bar, with four tabs:
//
//   Dashboard    the 12 hour ring, you, the calendar with the agenda inside
//                it (AgendaCalendar), the player
//   Performance  CPU/GPU, battery as a gauge, storage, network, memory
//   Apps         every app with a window, by memory, close or kill on hover
//   Cockpits     devpit's repos: git line, CI, pull requests, agents
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
    // The Dashboard tab: the 12 hour ring on the left; you, then the calendar
    // with the agenda inside it (AgendaCalendar) in the middle; the player on
    // the right.
    component DashTab: GridLayout {
        id: dash
        columns: 3
        rowSpacing: 10
        columnSpacing: 10

        // The 12 hour ring, the full height on the left.
        Card {
            Layout.row: 0; Layout.column: 0; Layout.rowSpan: 2
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            DayRing { anchors.centerIn: parent }
        }

        // You, with your picture beside you.
        Card {
            Layout.row: 0; Layout.column: 1
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            clip: true
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
            AnimatedImage {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; margins: 8 }
                width: height
                fillMode: Image.PreserveAspectFit
                // Settings, Desktop: any gif; empty means the bundled one.
                source: AshuraSettings.dashboardGif !== "" ? `file://${AshuraSettings.dashboardGif}` : Quickshell.shellPath("assets/ashura/dashboard.gif")
                playing: root.shown && root.tab === 0
            }
        }

        // The month with the agenda inside it (AgendaCalendar).
        Card {
            Layout.row: 1; Layout.column: 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            AgendaCalendar { anchors.fill: parent }
        }

        // The player, the full height on the right.
        Card {
            Layout.row: 0; Layout.column: 2; Layout.rowSpan: 2
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            MiniPlayer { anchors.fill: parent; anchors.margins: 14 }
        }
    }

    // A 12 hour clock face. The ring starts at the top (12 o'clock). From
    // midnight to noon the morning colour grows over a grey track; at noon
    // the full morning ring becomes the track and the afternoon colour grows
    // over it. AM or PM shows under the time.
    component DayRing: Item {
        id: ring
        width: 214; height: 214
        readonly property date now: DateTime.clock.date
        readonly property bool pm: ring.now.getHours() >= 12
        readonly property real frac: ((ring.now.getHours() % 12) * 3600 + ring.now.getMinutes() * 60 + ring.now.getSeconds()) / 43200
        // Both from the wallpaper's palette: tertiary for the morning, the
        // accent for the afternoon.
        readonly property color amColor: Appearance.colors.colTertiary
        readonly property color pmColor: Appearance.colors.colPrimary
        readonly property real r: 88
        Repeater {
            model: 12
            delegate: Item {
                required property int index
                anchors.centerIn: parent
                width: ring.width; height: ring.height
                rotation: index * 30
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1
                    width: 2; height: index % 3 === 0 ? 9 : 5
                    radius: 1
                    color: index % 3 === 0 ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
                    opacity: index % 3 === 0 ? 0.9 : 0.6
                }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {   // the track: grey in the morning, the full morning ring after noon
                fillColor: "transparent"; strokeColor: ring.pm ? ring.amColor : Appearance.colors.colOutlineVariant; strokeWidth: 12
                PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: ring.pm ? ring.pmColor : ring.amColor; strokeWidth: 12; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: -90; sweepAngle: 360 * ring.frac }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 0
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                // A 12 hour face: AM/PM is under it. (Qt's "h" stays 0 to 23
                // unless the format itself has AP, so the hour is worked out.)
                text: `${(ring.now.getHours() + 11) % 12 + 1}:${String(ring.now.getMinutes()).padStart(2, "0")}`
                font.pixelSize: 44
                font.family: Appearance.font.family.numbers
                font.weight: Font.DemiBold
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ring.pm ? "PM" : "AM"
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                font.letterSpacing: 2
                color: ring.pm ? ring.pmColor : ring.amColor
            }
            SubLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 2
                text: Qt.formatDateTime(ring.now, "dddd, d MMMM")
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
    // Power profile colours: green for saving, the theme's colour for balanced,
    // warm for performance. The battery card fills in the active one.
    function profileColour(profile) {
        return profile === PowerProfile.PowerSaver ? "#7fcf8a"
            : profile === PowerProfile.Performance ? "#ff8a5c" : Appearance.colors.colPrimary;
    }
    function profileInk(profile) {
        return profile === PowerProfile.PowerSaver ? "#0f2412"
            : profile === PowerProfile.Performance ? "#2b1206" : Appearance.colors.colOnPrimary;
    }

    // The text of the battery card; the card itself is the gauge (BatteryCard).
    // "Plugged in" covers a full battery or one held below 100% by the charge
    // limit (UPower then reports "fully charged" or "pending", not "charging").
    component BatteryBlock: ColumnLayout {
        id: batt
        readonly property bool onAc: !UPower.onBattery
        spacing: 2
        RowLayout {
            spacing: 4
            MaterialSymbol {
                visible: batt.onAc
                text: "bolt"
                fill: 1
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer2
            }
            SubLabel { text: Battery.isCharging ? Translation.tr("Charging") : batt.onAc ? Translation.tr("Plugged in") : Translation.tr("On battery") }
        }
        Item { Layout.fillHeight: true }
        Label {
            text: `${Math.round(Battery.percentage * 100)}%`
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
        // Battery, tall, with the power profile under it. The card is the
        // battery: it fills from the bottom to the charge level, in the colour
        // of the active power profile.
        Card {
            id: battCard
            Layout.row: 0; Layout.column: 2; Layout.rowSpan: 2
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * Battery.percentage
                readonly property bool full: Battery.percentage > 0.97
                bottomLeftRadius: battCard.radius
                bottomRightRadius: battCard.radius
                topLeftRadius: full ? battCard.radius : 0
                topRightRadius: full ? battCard.radius : 0
                color: Qt.alpha(root.profileColour(PowerProfiles.profile), Battery.isLowAndNotCharging ? 0.5 : 0.22)
                Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
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
                        colBackgroundToggled: root.profileColour(modelData.profile)
                        colBackgroundToggledHover: root.profileColour(modelData.profile)
                        onClicked: PowerProfiles.profile = modelData.profile
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol { text: modelData.icon; iconSize: Appearance.font.pixelSize.larger
                                color: active ? root.profileInk(modelData.profile) : Appearance.colors.colOnLayer2 }
                            StyledText { text: modelData.name; color: active ? root.profileInk(modelData.profile) : Appearance.colors.colOnLayer2 }
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
    // A small status chip for the Cockpits tab; `pulse` blinks its icon.
    component CockpitChip: Rectangle {
        id: chip
        property string icon
        property string label
        property color tint: Appearance.colors.colLayer1
        property color ink: Appearance.colors.colOnLayer1
        property bool pulse: false
        implicitWidth: chipRow.implicitWidth + 14
        implicitHeight: 24
        radius: 12
        color: chip.tint
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                iconSize: 14
                color: chip.ink
                SequentialAnimation on opacity {
                    running: chip.pulse
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: chip.ink
            }
        }
    }

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
                        StyledText { text: Translation.tr("Add a repo"); color: Appearance.colors.colOnSecondaryContainer }
                    }
                }
            }
        }

        // CI, pull requests and running agents per repo (scripts/ashura/cockpit-status),
        // polled while this tab is open; GitHub answers are cached for two minutes.
        Process {
            id: statusProc
            property var data: ({})
            command: [Quickshell.shellPath("scripts/ashura/cockpit-status")]
            stdout: StdioCollector { onStreamFinished: { try { statusProc.data = JSON.parse(text).repos ?? {}; } catch (e) {} } }
        }
        Timer {
            interval: 20000; repeat: true; triggeredOnStart: true
            running: root.shown && root.tab === 3
            onTriggered: if (!statusProc.running) statusProc.running = true
        }

        // Panel style C3: a row per repo with a small git line (history, the
        // remote's marker, your unpushed commits past it) and chips for changed
        // files, CI, pull requests and agents. Hover lifts the row, spreads the
        // line and brings in the actions.
        StyledListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            // Keyed by id: a refresh updates rows in place, no rebuild flash.
            model: ScriptModel { values: Cockpit.cockpits; objectProp: "id" }
            delegate: Item {
                id: row
                required property var modelData
                readonly property bool onStage: Cockpit.current === modelData.id
                readonly property int windows: Cockpit.repos[modelData.id]?.windows ?? 0
                readonly property var git: modelData.git ?? {}
                readonly property var extra: statusProc.data[modelData.id] ?? ({})
                readonly property bool hot: rowHover.containsMouse || goBtn.hovered || closeBtn.hovered
                width: ListView.view.width
                height: 64

                Card {
                    id: rowCard
                    anchors.fill: parent
                    anchors.topMargin: row.hot ? 0 : 3
                    anchors.bottomMargin: row.hot ? 3 : 0
                    color: row.onStage ? Appearance.colors.colSecondaryContainer
                        : row.hot ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
                    Behavior on anchors.topMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on anchors.bottomMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    MouseArea { id: rowHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                    Column {
                        id: nameCol
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        width: 130
                        Label { width: parent.width; elide: Text.ElideRight; text: row.modelData.name; font.weight: Font.DemiBold }
                        SubLabel { width: parent.width; elide: Text.ElideRight; text: row.git.branch ?? ""; font.family: Appearance.font.family.monospace }
                    }

                    // The git line.
                    Item {
                        id: gitLine
                        anchors { left: nameCol.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        width: 222; height: 30
                        property real gap: row.hot ? 15 : 11
                        Behavior on gap { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        readonly property real originX: 8 + gap * 5
                        Rectangle { y: 14; x: 2; width: gitLine.originX + gitLine.gap * Math.min(6, row.git.ahead ?? 0) + 8; height: 2; radius: 1; color: Appearance.colors.colOutlineVariant }
                        Repeater {   // history
                            model: 5
                            delegate: Rectangle { required property int index; x: 8 + index * gitLine.gap - 4; y: 11; width: 8; height: 8; radius: 4; color: Appearance.colors.colSubtext }
                        }
                        Rectangle {   // the remote's marker
                            x: gitLine.originX; y: 5; width: 2; height: 20; radius: 1; color: Appearance.colors.colOnLayer2
                            StyledText { anchors { top: parent.bottom; horizontalCenter: parent.horizontalCenter } text: "origin"; font.pixelSize: 9; color: Appearance.colors.colSubtext }
                        }
                        Repeater {   // unpushed
                            model: Math.min(6, row.git.ahead ?? 0)
                            delegate: Rectangle {
                                required property int index
                                x: gitLine.originX + gitLine.gap * (index + 1) - 5; y: 10; width: 10; height: 10; radius: 5
                                color: Appearance.colors.colPrimary
                            }
                        }
                        StyledText {
                            visible: (row.git.ahead ?? 0) > 6
                            x: gitLine.originX + gitLine.gap * 7; anchors.verticalCenter: parent.verticalCenter
                            text: `+${(row.git.ahead ?? 0) - 6}`
                            font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colPrimary
                        }
                    }

                    // Chips: changed files, CI, pull requests, agents (CockpitChip).
                    Row {
                        anchors { left: gitLine.right; leftMargin: 10; right: actions.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 5
                        clip: true
                        CockpitChip {
                            visible: (row.git.dirty ?? 0) + (row.git.untracked ?? 0) > 0
                            icon: "edit_note"; label: `${(row.git.dirty ?? 0) + (row.git.untracked ?? 0)}`
                            tint: "#e2b25c"; ink: "#2a1d08"
                        }
                        CockpitChip {
                            readonly property string st: row.extra.ci?.state ?? "none"
                            visible: st !== "none"
                            icon: st === "success" ? "check_circle" : st === "failure" ? "cancel" : "pending"
                            label: st === "success" ? "CI" : st === "failure" ? Translation.tr("CI failed") : Translation.tr("CI running")
                            tint: st === "success" ? "#7fcf8a" : st === "failure" ? Appearance.colors.colError : Appearance.colors.colLayer1
                            ink: st === "success" ? "#0f2412" : st === "failure" ? Appearance.colors.colOnError : Appearance.colors.colOnLayer1
                            pulse: st === "running"
                        }
                        CockpitChip {
                            readonly property var prs: row.extra.prs ?? ({ open: 0 })
                            visible: prs.open > 0
                            icon: "merge"
                            label: prs.mine ? `#${prs.mine.number}${prs.mine.draft ? " draft" : ""}` : Translation.tr("%1 PR").arg(prs.open)
                        }
                        Repeater {
                            model: row.extra.agents ?? []
                            delegate: CockpitChip {
                                required property var modelData
                                icon: "smart_toy"
                                label: `${modelData.name} · ${modelData.busy ? Translation.tr("working") : Translation.tr("idle")}`
                                tint: modelData.busy ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                ink: modelData.busy ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                pulse: modelData.busy
                            }
                        }
                        CockpitChip {
                            visible: row.windows > 0
                            icon: "select_window"; label: `${row.windows}`
                        }
                    }

                    // Actions, in on hover (and always for the repo on stage).
                    Row {
                        id: actions
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        opacity: row.hot || row.onStage ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        RippleButton {
                            id: goBtn
                            implicitWidth: 36; implicitHeight: 36; buttonRadius: 18
                            onClicked: { root.pinned = false; row.onStage ? Cockpit.toggle() : Cockpit.open(row.modelData.id); }
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: row.onStage ? "swap_horiz" : "play_arrow"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer2 }
                            StyledToolTip { text: row.onStage ? Translation.tr("Go in / out") : Translation.tr("Open in the cockpit") }
                        }
                        RippleButton {
                            id: closeBtn
                            visible: row.windows > 0
                            implicitWidth: 36; implicitHeight: 36; buttonRadius: 18
                            onClicked: Cockpit.close(row.modelData.id)
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer2 }
                            StyledToolTip { text: Translation.tr("Close this repo's windows") }
                        }
                    }
                }
            }
            PagePlaceholder {
                shown: Cockpit.loaded && Cockpit.cockpits.length === 0
                icon: "rocket_launch"
                title: Translation.tr("No cockpits yet")
                description: Translation.tr("Add a repo with the button above")
            }
        }
    }
}
