pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Docker on this machine, read from the docker CLI.
 *
 * The daemon is checked with systemctl first, so a stopped daemon reads as
 * "off" instead of being started by the poll (docker.socket would otherwise
 * activate it on every `docker ps`).
 *
 * Containers are polled for the bar pill. Images and volumes (with sizes) cost a
 * `docker system df -v`, so they are only fetched while something shows them
 * (`detailsWanted`, set by the sidebar tab) and after an action.
 *
 * Actions go through devpit (`devpit do container.<verb> <name> --yes --json`) so
 * every side effect lives in one auditable CLI with real error messages.
 */
Singleton {
    id: root

    property bool daemonRunning: false
    property bool cliAvailable: true
    // Each: { name, state, status, image, project }
    property var containers: []
    readonly property int running: containers.filter(c => c.state === "running").length
    readonly property int total: containers.length
    property int pollInterval: 5000

    property bool detailsWanted: false
    // Each: { repo, tag, size, containers }
    property var images: []
    // Each: { name, size, links }   links = containers using it
    property var volumes: []
    property string busy: ""          // container name with an action in flight

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    function refreshDetails() {
        if (!detailsProc.running)
            detailsProc.running = true;
    }

    onDetailsWantedChanged: if (detailsWanted) refreshDetails()

    // start | stop | restart
    function containerAction(verb, name) {
        root.busy = name;
        actionProc.command = ["bash", "-c",
            'if command -v devpit >/dev/null; then exec devpit "$@"; else exec "$HOME/.local/bin/devpit" "$@"; fi',
            "devpit", "do", `container.${verb}`, name, "--yes", "--json"];
        actionProc.running = true;
    }

    function openLogs(name) {
        Quickshell.execDetached(["kitty", "--title", `logs: ${name}`, "docker", "logs", "-f", "--tail", "200", name]);
    }

    function startDaemon() {
        // systemctl asks polkit, which shows the shell's own password prompt.
        Quickshell.execDetached(["systemctl", "start", "docker.service"]);
    }

    // Compose writes the project name into a label; it lets the UI group a
    // stack's containers together.
    function projectOf(labels) {
        const m = /(?:^|,)com\.docker\.compose\.project=([^,]+)/.exec(labels ?? "");
        return m ? m[1] : "";
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: listProc
        command: ["bash", "-c",
            "command -v docker >/dev/null || exit 127; " +
            "systemctl is-active --quiet docker.service || exit 3; " +
            "docker ps -a --format '{{json .}}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = [];
                for (const line of text.split("\n")) {
                    if (line.trim().length === 0)
                        continue;
                    try {
                        const o = JSON.parse(line);
                        parsed.push({
                            name: o.Names,
                            state: o.State,
                            status: o.Status,
                            image: o.Image,
                            project: root.projectOf(o.Labels)
                        });
                    } catch (e) {
                        console.warn("[Docker] skipped unparsable line:", line);
                    }
                }
                // Compose stacks first (grouped), standalone containers last, each by
                // name, so the list is stable between polls.
                parsed.sort((a, b) => (!a.project - !b.project) || a.project.localeCompare(b.project) || a.name.localeCompare(b.name));
                root.containers = parsed;
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.cliAvailable = exitCode !== 127;
            const wasRunning = root.daemonRunning;
            root.daemonRunning = exitCode === 0;
            if (exitCode !== 0)
                root.containers = [];
            if (root.daemonRunning && !wasRunning && root.detailsWanted)
                root.refreshDetails();
        }
    }

    Process {
        id: detailsProc
        command: ["bash", "-c",
            "systemctl is-active --quiet docker.service || exit 3; " +
            "docker system df -v --format '{{json .}}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0) {
                    root.images = [];
                    root.volumes = [];
                    return;
                }
                try {
                    const d = JSON.parse(text);
                    root.images = (d.Images ?? []).map(i => ({
                        repo: i.Repository,
                        tag: i.Tag,
                        size: i.Size,
                        containers: parseInt(i.Containers) || 0
                    }));
                    root.volumes = (d.Volumes ?? []).map(v => ({
                        name: v.Name,
                        size: v.Size,
                        links: parseInt(v.Links) || 0
                    }));
                } catch (e) {
                    console.warn("[Docker] could not read docker system df:", e);
                }
            }
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                let message = "";
                try {
                    message = JSON.parse(text).message ?? "";
                } catch (e) {
                    message = "";
                }
                if (message.length > 0)
                    Quickshell.execDetached(["notify-send", "Docker", message, "-a", "Shell"]);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // devpit prints a human-readable reason on failure.
                if (text.trim().length > 0)
                    Quickshell.execDetached(["notify-send", "Docker", text.trim(), "-a", "Shell", "-u", "critical"]);
            }
        }
        onExited: {
            root.busy = "";
            root.refresh();
            if (root.detailsWanted)
                root.refreshDetails();
        }
    }
}
