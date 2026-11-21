import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The sidebar's Docker tab: Containers / Images / Volumes, laid out like the
// To Do widget (secondary tab bar over a swipe view of lists).
//
// Containers can be started, stopped, restarted and their logs opened. Images
// and volumes are listed with sizes and what uses them, but nothing here deletes
// them: a volume can hold a real database (LienRho's does), so removal stays a
// deliberate `devpit do` from a terminal.
Item {
    id: root
    property var tabButtonList: [
        { "icon": "deployed_code", "name": Translation.tr("Containers") },
        { "icon": "layers", "name": Translation.tr("Images") },
        { "icon": "database", "name": Translation.tr("Volumes") }
    ]

    // Images and volumes cost a `docker system df`; fetch them only while shown.
    Component.onCompleted: Docker.detailsWanted = true
    Component.onDestruction: Docker.detailsWanted = false

    readonly property string offText: Docker.cliAvailable ? Translation.tr("Docker is not running") : Translation.tr("Docker is not installed")

    function containerItems() {
        const out = [];
        let group = null;
        for (const c of Docker.containers) {
            const g = c.project || Translation.tr("Standalone");
            if (g !== group) {
                out.push({ key: `h:${g}`, header: g });
                group = g;
            }
            const running = c.state === "running";
            // Any action in flight pauses every button: Docker.qml runs one action
            // at a time, so a second click would silently replace the first.
            const busy = Docker.busy !== "";
            const actions = running ? [
                { icon: "stop", tooltip: Translation.tr("Stop"), verb: "stop", enabled: !busy },
                { icon: "restart_alt", tooltip: Translation.tr("Restart"), verb: "restart", enabled: !busy }
            ] : [
                { icon: "play_arrow", tooltip: Translation.tr("Start"), verb: "start", enabled: !busy }
            ];
            actions.push({ icon: "article", tooltip: Translation.tr("Logs"), verb: "logs", enabled: true });
            out.push({
                key: `c:${c.name}:${c.state}:${c.status}:${busy}`,
                target: c.name,
                icon: running ? "play_circle" : "stop_circle",
                iconFilled: running,
                title: c.name,
                subtitle: `${c.image} · ${c.status}`,
                actions: actions
            });
        }
        return out;
    }

    function usedBy(n) {
        return n > 0 ? Translation.tr("used by %1").arg(n) : Translation.tr("unused");
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SecondaryTabBar {
            id: tabBar
            currentIndex: swipeView.currentIndex
            Repeater {
                model: root.tabButtonList
                delegate: SecondaryTabButton {
                    buttonText: modelData.name
                    buttonIcon: modelData.icon
                }
            }
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            currentIndex: tabBar.currentIndex

            DockerList {
                items: Docker.daemonRunning ? root.containerItems() : []
                onTriggered: (target, verb) => verb === "logs" ? Docker.openLogs(target) : Docker.containerAction(verb, target)
                emptyPlaceholderIcon: Docker.daemonRunning ? "deployed_code" : "power_settings_new"
                emptyPlaceholderText: Docker.daemonRunning ? Translation.tr("No containers") : root.offText
                emptyActionText: (!Docker.daemonRunning && Docker.cliAvailable) ? Translation.tr("Start Docker") : ""
                emptyAction: () => Docker.startDaemon()
            }

            DockerList {
                items: Docker.daemonRunning ? Docker.images.map((i, n) => ({
                    key: `i:${n}:${i.repo}:${i.tag}:${i.size}:${i.containers}`, // n: unnamed images can repeat
                    icon: "layers",
                    title: `${i.repo}:${i.tag}`,
                    subtitle: `${i.size} · ${root.usedBy(i.containers)}`
                })) : []
                emptyPlaceholderIcon: Docker.daemonRunning ? "layers" : "power_settings_new"
                emptyPlaceholderText: Docker.daemonRunning ? Translation.tr("No images") : root.offText
            }

            DockerList {
                items: Docker.daemonRunning ? Docker.volumes.map((v, n) => ({
                    key: `v:${n}:${v.name}:${v.size}:${v.links}`,
                    icon: "database",
                    title: v.name,
                    subtitle: `${v.size} · ${root.usedBy(v.links)}`
                })) : []
                emptyPlaceholderIcon: Docker.daemonRunning ? "database" : "power_settings_new"
                emptyPlaceholderText: Docker.daemonRunning ? Translation.tr("No volumes") : root.offText
            }
        }
    }
}
