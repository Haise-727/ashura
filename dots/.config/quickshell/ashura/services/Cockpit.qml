pragma Singleton

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura cockpit, shell side.
 *
 * The window work happens in Hyprland (hypr/custom/cockpit.lua, global
 * `ashura_cockpit`); the list of cockpits and what each launches comes from devpit.
 * This service joins the two: it reads the state file the Lua writes, asks devpit
 * for lists and launch specs, and calls the Lua through `hyprctl eval`.
 *
 * Nothing here runs at login beyond watching one small file. devpit is only asked
 * when the picker (the "@" search prefix) is open or an action needs it.
 */
Singleton {
    id: root

    readonly property string prefix: "@"
    readonly property string stateFile: `${Directories.home}/.local/state/ashura/cockpit.json`

    // From the Lua state file
    property string current: ""
    property string currentName: ""
    property bool visible: false
    property var repos: ({})            // id -> { name, windows }

    // From devpit, refreshed on demand
    property var cockpits: []           // devpit cockpit list --json
    property bool loaded: false         // the list has been read once
    property var candidates: []         // devpit cockpit candidates --json
    property string lastError: ""

    function windowsOf(id) {
        return root.repos[id]?.windows ?? 0;
    }

    // ------------------------------------------------------------ actions
    function toggle() { root.lua("ashura_cockpit.toggle()"); }
    function openPicker() { Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.global("quickshell:cockpitPicker")']); }
    function hide() { root.lua("ashura_cockpit.hide()"); }
    function close(id) { root.lua(`ashura_cockpit.close(${root.luaString(id)})`); }

    function open(id) { root.enqueue("spec", ["cockpit", "spec", id, "--json"]); }
    function add(path) { root.enqueue("add", ["cockpit", "add", path, "--json"]); }

    // Removing a cockpit closes its windows first, so nothing is left tagged to a
    // repo the list no longer knows about. The repo itself is never touched.
    function remove(id) {
        root.close(id);
        root.enqueue("remove", ["cockpit", "remove", id, "--json"]);
    }

    // Coalesced: many window events in a row cost one devpit run, not one each.
    function refresh() { refreshTimer.restart(); }
    // Read the list once soon after start, so the dashboard's Cockpits tab
    // has rows the first time it opens instead of "No cockpits yet".
    Timer { interval: 4000; running: true; onTriggered: root.refresh() }

    // ------------------------------------------------------------ job queue
    // devpit calls that change something run one at a time, in order. A single
    // Process ignores a new command while it is busy, which silently dropped a
    // second quick open or remove.
    property var jobs: []
    function enqueue(kind, args) {
        root.jobs = root.jobs.concat([{ kind: kind, args: args }]);
        root.runNextJob();
    }
    function runNextJob() {
        if (jobProc.running || root.jobs.length === 0) return;
        const job = root.jobs[0];
        root.jobs = root.jobs.slice(1);
        jobProc.kind = job.kind;
        jobProc.command = root.devpit(job.args);
        jobProc.running = true;
    }
    function finishJob(kind, text) {
        const d = root.parse(text, `cockpit ${kind}`);
        if (!d) return;
        if (kind === "spec") {
            if (!d.exists) {
                Quickshell.execDetached(["notify-send", "Cockpit", `${d.path} is gone; remove its cockpit`, "-a", "Shell"]);
                return;
            }
            const cmds = d.launch.map(item => root.luaString(item.shell)).join(", ");
            root.lua(`ashura_cockpit.open(${root.luaString(d.id)}, ${root.luaString(d.name)}, { ${cmds} }, ${d.unique_name === false ? "false" : "true"})`);
        } else if (kind === "add") {
            root.refresh();
            root.open(d.cockpit.id);
        } else if (kind === "remove") {
            root.refresh();
        }
    }

    // ------------------------------------------------------------ plumbing
    // devpit is usually on PATH, but a session started by the display manager may
    // not have ~/.local/bin on it, so fall back to the full path.
    function devpit(args) {
        return ["bash", "-c", 'if command -v devpit >/dev/null; then exec devpit "$@"; else exec "$HOME/.local/bin/devpit" "$@"; fi', "devpit"].concat(args);
    }

    // A Lua double-quoted string. Every control character becomes a decimal
    // escape: a raw CR (or any other) inside a Lua short string is a syntax error.
    function luaString(s) {
        return '"' + String(s).replace(/[\\"\x00-\x1f\x7f]/g, c => "\\" + String(c.charCodeAt(0)).padStart(3, "0")) + '"';
    }

    function lua(code) {
        Quickshell.execDetached(["hyprctl", "eval", code]);
    }

    function parse(text, what) {
        try {
            const data = JSON.parse(text);
            if (data.error) {
                root.lastError = data.error;
                Quickshell.execDetached(["notify-send", "Cockpit", data.error, "-a", "Shell"]);
                return null;
            }
            return data;
        } catch (e) {
            root.lastError = `${what}: devpit returned no usable output`;
            return null;
        }
    }

    // `qs -c ashura ipc call cockpit <fn> [arg]`, for scripts and keybinds.
    IpcHandler {
        target: "cockpit"
        function toggle(): void { root.toggle(); }
        function hide(): void { root.hide(); }
        function open(id: string): void { root.open(id); }
        function close(id: string): void { root.close(id); }
        function remove(id: string): void { root.remove(id); }
        function add(path: string): void { root.add(path); }
        function picker(): void { root.openPicker(); }
    }

    // Ask devpit for fresh lists when the picker opens (the query becomes exactly
    // the prefix), not on every keystroke and never from inside a binding.
    Connections {
        target: LauncherSearch
        function onQueryChanged() {
            if (LauncherSearch.query === root.prefix) root.refresh();
        }
    }

    // A repo opening or closing changes its "on stage / waiting" line. The window
    // counts in the state file change far more often than the list does, so this
    // goes through the coalescing timer.
    onReposChanged: if (GlobalStates.overviewOpen && LauncherSearch.query.startsWith(root.prefix)) root.refresh()

    FileView {
        id: stateView
        path: root.stateFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.current = s.current ?? "";
                root.currentName = s.currentName ?? "";
                root.visible = s.visible ?? false;
                root.repos = s.repos ?? {};
            } catch (e) {
                // Half-written file during a rename; the next change reloads it.
            }
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text, "cockpit list");
                if (d) root.cockpits = d.cockpits;
                root.loaded = true;
            }
        }
    }

    Process {
        id: candidatesProc
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text, "cockpit candidates");
                if (d) root.candidates = d.candidates;
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: {
            if (!listProc.running) {
                listProc.command = root.devpit(["cockpit", "list", "--json"]);
                listProc.running = true;
            }
            if (!candidatesProc.running) {
                candidatesProc.command = root.devpit(["cockpit", "candidates", "--json"]);
                candidatesProc.running = true;
            }
        }
    }

    Process {
        id: jobProc
        property string kind: ""
        stdout: StdioCollector {
            onStreamFinished: root.finishJob(jobProc.kind, text)
        }
        onExited: root.runNextJob()
    }
}
