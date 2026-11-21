import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

// Hover card for the Docker pill: one row per container, the same header and
// value rows the Resources popup uses.
StyledPopup {
    id: root

    function stateIcon(state) {
        switch (state) {
        case "running": return "play_circle";
        case "paused": return "pause_circle";
        case "restarting": return "autorenew";
        default: return "stop_circle";
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8

        StyledPopupHeaderRow {
            icon: "deployed_code"
            label: "Docker"
        }

        Column {
            spacing: 4
            visible: Docker.daemonRunning && Docker.total > 0

            Repeater {
                model: Docker.containers
                delegate: StyledPopupValueRow {
                    required property var modelData
                    width: 260
                    icon: root.stateIcon(modelData.state)
                    label: modelData.name
                    value: modelData.state
                }
            }
        }

        StyledPopupValueRow {
            visible: !Docker.daemonRunning || Docker.total === 0
            icon: Docker.daemonRunning ? "inbox" : "power_settings_new"
            label: Docker.daemonRunning ? Translation.tr("No containers") : Translation.tr("Daemon is not running")
            value: ""
        }
    }
}
