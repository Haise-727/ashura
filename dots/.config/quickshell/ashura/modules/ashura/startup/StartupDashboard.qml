import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ashura.mediaControls
import qs.modules.ashura.sidebarRight.notifications
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Ashura: the startup workspace (ws10). While ws10 is focused the bar hides and this
// fills the screen, above the wallpaper and below any windows. Cards follow the
// August spec: profile, a big clock, media with cava (and the lofi radio), a gif,
// notifications, battery and a little system data. Each card is built from the
// shell's own pieces (PlayerControl, NotificationList, the services) in its card style.
Scope {
    id: root
    readonly property int startupWorkspace: 10   // Haise's "special" workspace (was 6 until 2026-11-09)
    readonly property bool active: HyprlandData.activeWorkspace?.id === root.startupWorkspace
    readonly property list<real> visualizerPoints: CavaFeed.points
    property bool hidBar: false

    // Hide the bar on ws10 and put it back on leaving, but only if we hid it.
    onActiveChanged: {
        if (root.active && GlobalStates.barOpen) {
            GlobalStates.barOpen = false;
            root.hidBar = true;
        } else if (!root.active && root.hidBar) {
            GlobalStates.barOpen = true;
            root.hidBar = false;
        }
    }

    Binding { target: CavaFeed; property: "wantDashboard"; value: root.active }

    component Card: Rectangle {
        default property alias content: inner.data
        property string title: ""
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.windowRounding
        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10
        }
    }
    component CardTitle: StyledText {
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        color: Appearance.colors.colSubtext
    }
    component InfoRow: RowLayout {
        property string icon
        property string label
        property string value
        spacing: 8
        MaterialSymbol { text: parent.icon; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer1 }
        StyledText { Layout.fillWidth: true; text: parent.label; color: Appearance.colors.colOnLayer1 }
        StyledText { text: parent.value; color: Appearance.colors.colSubtext }
    }

    LazyLoader {
        active: root.active
        component: PanelWindow {
            id: win
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            // The whole screen belongs to the dashboard on ws10, so
            // the wallpaper and desktop clock sit behind a near-solid backdrop.
            color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.08)
            WlrLayershell.namespace: "quickshell:startupDashboard"
            WlrLayershell.layer: WlrLayer.Bottom

            GridLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 160, 1280)
                height: Math.min(parent.height - 160, 760)
                columns: 3
                rowSpacing: 16
                columnSpacing: 16

                // ---------------------------------------------------- profile
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.fillHeight: true
                    RowLayout {
                        spacing: 16
                        Item {
                            implicitWidth: 88
                            implicitHeight: 88
                            Image {
                                id: avatar
                                anchors.fill: parent
                                source: `${Directories.home}/.face`
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(176, 176)
                                visible: false
                            }
                            OpacityMask {
                                anchors.fill: parent
                                source: avatar
                                maskSource: Rectangle { width: 88; height: 88; radius: 44 }
                                visible: avatar.status === Image.Ready
                            }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: avatar.status !== Image.Ready
                                text: "account_circle"
                                iconSize: 88
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                        ColumnLayout {
                            spacing: 2
                            StyledText {
                                text: SystemInfo.username
                                font.pixelSize: Appearance.font.pixelSize.title
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: Translation.tr("Up %1").arg(DateTime.uptime)
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                // ---------------------------------------------------- clock
                Card {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1
                    ColumnLayout {
                        Layout.alignment: Qt.AlignCenter
                        spacing: 0
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: DateTime.time
                            font.family: Appearance.font.family.expressive
                            font.pixelSize: 96
                            font.weight: Font.Bold
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.locale().toString(DateTime.clock.date, "dddd, d MMMM")
                            font.pixelSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }

                // ---------------------------------------------------- media + lofi
                Card {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1.3
                    RowLayout {
                        Layout.fillWidth: true
                        CardTitle { Layout.fillWidth: true; text: Translation.tr("Now playing") }
                        RippleButton {
                            implicitHeight: 32
                            implicitWidth: lofiLabel.implicitWidth + 44
                            buttonRadius: Appearance.rounding.full
                            colBackground: Lofi.playing ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                            onClicked: Lofi.toggle()
                            contentItem: RowLayout {
                                spacing: 6
                                MaterialSymbol { Layout.leftMargin: 12; text: Lofi.playing ? "stop" : "radio"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer1 }
                                StyledText { id: lofiLabel; text: Lofi.playing ? Lofi.stationName : Translation.tr("Lofi radio"); color: Appearance.colors.colOnLayer1 }
                            }
                        }
                        RippleButton {
                            visible: Lofi.playing
                            implicitHeight: 32
                            implicitWidth: 32
                            buttonRadius: Appearance.rounding.full
                            onClicked: Lofi.next()
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer1 }
                            StyledToolTip { text: Translation.tr("Next station") }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        PlayerControl {
                            visible: MprisController.activePlayer !== null
                            anchors.fill: parent
                            player: MprisController.activePlayer
                            visualizerPoints: root.visualizerPoints
                        }
                        StyledText {
                            anchors.centerIn: parent
                            visible: MprisController.activePlayer === null
                            text: Translation.tr("Nothing playing. The lofi radio is one click away.")
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // ---------------------------------------------------- gif
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1.3
                    AnimatedImage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        source: Quickshell.shellPath("assets/ashura/kurukuru.gif")
                        fillMode: Image.PreserveAspectFit
                        playing: root.active
                    }
                }

                // ---------------------------------------------------- notifications
                Card {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1.4
                    CardTitle { text: Translation.tr("Notifications") }
                    NotificationList {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }

                // ---------------------------------------------------- system
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 1.4
                    CardTitle { text: Translation.tr("System") }
                    InfoRow {
                        visible: Battery.available
                        icon: Battery.isCharging ? "battery_charging_full" : "battery_full"
                        label: Translation.tr("Battery")
                        value: `${Math.round(Battery.percentage * 100)}%`
                    }
                    InfoRow { icon: "planner_review"; label: Translation.tr("CPU"); value: `${Math.round(ResourceUsage.cpuUsage * 100)}%` }
                    InfoRow { icon: "memory"; label: Translation.tr("Memory"); value: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%` }
                    InfoRow { icon: "deployed_code"; label: Translation.tr("Containers"); value: Docker.daemonRunning ? `${Docker.running}/${Docker.total}` : Translation.tr("off") }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
