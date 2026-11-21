import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ashura.sidebarRight.docker
import QtQuick
import QtQuick.Layouts

// The sidebar's Apps tab: every app with a window, heaviest first, with its CPU
// and memory (whole process tree). Close asks the app nicely (its windows get a
// close request, so unsaved work can still prompt); Force kill is SIGKILL.
// Same list component as the Docker tab.
Item {
    id: root
    Component.onCompleted: AppUsage.wanted = true
    Component.onDestruction: AppUsage.wanted = false

    DockerList {
        anchors.fill: parent
        items: AppUsage.apps.map(a => ({
            key: `a:${a.pid}:${a.cpu}:${a.memMb}:${a.windows}`,
            target: String(a.pid),
            icon: "apps",
            title: a.name,
            subtitle: `${a.memMb} MB · ${a.cpu}% CPU · ${a.windows} ${a.windows === 1 ? Translation.tr("window") : Translation.tr("windows")}`,
            actions: [
                { icon: "close", tooltip: Translation.tr("Close"), verb: "close", enabled: true },
                { icon: "dangerous", tooltip: Translation.tr("Force kill"), verb: "kill", enabled: true }
            ]
        }))
        emptyPlaceholderIcon: "apps"
        emptyPlaceholderText: Translation.tr("No apps with windows")
        onTriggered: (target, verb) => verb === "kill" ? AppUsage.killApp(parseInt(target)) : AppUsage.closeApp(parseInt(target))
    }
}
