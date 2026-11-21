pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura: per-app resource use, Windows-task-manager style (August spec §18).
 *
 * An "app" is a process that owns at least one window. Its CPU and memory include
 * every process below it (browsers and editors are process trees). Polled only
 * while something shows it (`wanted`, set by the sidebar's Apps tab).
 */
Singleton {
    id: root

    property bool wanted: false
    property int interval: 3000
    // Each: { pid, name, cpu, memMb, windows, addresses }
    property var apps: []
    property var prevCpu: ({})       // pid -> cpu seconds at the last poll
    property real prevTime: 0
    property var children: ({})      // ppid -> [pid], from the last poll

    onWantedChanged: if (wanted) refresh()

    function refresh() { if (!proc.running) proc.running = true; }

    // Close every window of the app, as its own close button would.
    function closeApp(pid) {
        const app = root.apps.find(a => a.pid === pid);
        if (!app) return;
        for (const a of app.addresses)
            Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.window.close({ window = "address:${a}" })`]);
    }
    // Force: SIGKILL the app and every process below it (from the last poll).
    function killApp(pid) {
        if (pid === Quickshell.processId) return;             // never the shell itself
        const all = [], stack = [pid];
        while (stack.length) {
            const q = stack.pop();
            if (all.includes(q) || q === Quickshell.processId) continue;
            all.push(q);
            for (const ch of (root.children[q] || [])) stack.push(ch);
        }
        Quickshell.execDetached(["kill", "-KILL"].concat(all.map(String)));
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer
        interval: root.interval
        running: root.wanted
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        // Window owners from Hyprland, the whole process table from ps, as one
        // blob split by a marker line.
        // cputimes: CPU seconds used so far; the difference between two polls is
        // the current load (ps's own pcpu is a lifetime average).
        // Memory is PSS from scripts/ashura/proctable.py (shared pages split
        // between their users); ps's RSS counted them in full per process.
        command: ["bash", "-c", `hyprctl clients -j; echo '@@PS@@'; python3 '${FileUtils.trimFileProtocol(Directories.scriptPath)}/ashura/proctable.py'`]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("@@PS@@");
                if (parts.length < 2) return;
                let clients = [];
                try { clients = JSON.parse(parts[0]); } catch (e) { return; }
                const procs = {}, children = {};
                const now = Date.now() / 1000;
                const dt = root.prevTime > 0 ? Math.max(0.5, now - root.prevTime) : 0;
                const prev = root.prevCpu, seenCpu = {};
                for (const line of parts[1].split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+(.+)$/);
                    if (!m) continue;
                    const secs = +m[3];
                    seenCpu[+m[1]] = secs;
                    const used = (dt > 0 && prev[+m[1]] !== undefined) ? Math.max(0, secs - prev[+m[1]]) / dt * 100 : 0;
                    const p = { pid: +m[1], ppid: +m[2], cpu: used, rss: +m[4], comm: m[5] };
                    procs[p.pid] = p;
                    (children[p.ppid] = children[p.ppid] || []).push(p.pid);
                }
                // Group windows by owning pid, then sum each owner's tree.
                const owners = {};
                root.prevCpu = seenCpu;
                root.prevTime = now;
                root.children = children;
                for (const c of clients) {
                    if (!c.pid || c.pid <= 0 || c.pid === Quickshell.processId) continue;  // not the shell's own windows
                    const o = owners[c.pid] || (owners[c.pid] = { pid: c.pid, cls: c.class || c.initialClass || "", addresses: [] });
                    o.addresses.push(c.address);
                }
                const out = [];
                for (const pid in owners) {
                    const o = owners[pid];
                    let cpu = 0, rss = 0;
                    const stack = [o.pid], seen = {};
                    while (stack.length) {
                        const q = stack.pop();
                        if (seen[q] || !procs[q]) continue;
                        // A child that owns windows itself (a GUI app started from a
                        // terminal) has its own row; don't count it twice.
                        if (q !== o.pid && owners[q]) continue;
                        seen[q] = true;
                        cpu += procs[q].cpu;
                        rss += procs[q].rss;
                        for (const ch of (children[q] || [])) stack.push(ch);
                    }
                    out.push({
                        pid: o.pid,
                        name: o.cls || (procs[o.pid]?.comm ?? String(o.pid)),
                        cpu: Math.round(cpu),
                        memMb: Math.round(rss / 1024),
                        windows: o.addresses.length,
                        addresses: o.addresses
                    });
                }
                out.sort((a, b) => b.memMb - a.memMb);
                root.apps = out;
            }
        }
    }
}
