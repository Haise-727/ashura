pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Ashura: the SDDM login screen theme, chosen from qylock's themes.
 *
 * qylock lives in ~/.local/share/ashura/qylock (the installer clones it). Applying
 * a theme runs the root-owned /usr/local/bin/ashura-sddm-theme through pkexec, so
 * the password prompt is the normal polkit one; nothing here writes system files.
 */
Singleton {
    id: root

    readonly property string qylockDir: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/ashura/qylock`)
    readonly property string themesDir: `${root.qylockDir}/themes`
    readonly property string helper: "/usr/local/bin/ashura-sddm-theme"

    property var themes: []          // [{ name, preview }]
    property string current: ""      // theme folder name, e.g. "pixel-coffee"
    property string busy: ""         // theme being applied

    // qylock names its previews loosely: "pixel-coffee" -> "pixel_coffee.gif".
    readonly property var previewAliases: ({ "last-of-us": "the_last_of_us", "windows_7": "win7" })
    function previewFor(name) {
        const base = root.previewAliases[name] ?? name.toLowerCase().replace(/-/g, "_");
        return { a: `${root.qylockDir}/Assets/${base}.gif`, b: `${root.qylockDir}/Assets/${name.toLowerCase()}.gif` };
    }

    function refresh() {
        if (!listProc.running) listProc.running = true;
        currentView.reload();
    }

    function apply(name) {
        if (root.busy !== "") return;
        root.busy = name;
        // Check the helper first: pkexec reports a missing file with the same
        // code as a cancelled prompt.
        applyProc.command = ["bash", "-c", `[ -x "${root.helper}" ] || { echo "the login theme helper is not installed (run Ashura's installer)" >&2; exit 3; }; exec pkexec "$@"`,
            "pkexec", root.helper, "apply", name, root.themesDir];
        applyProc.running = true;
    }

    Process {
        id: listProc
        // Folders that are real SDDM themes, plus which preview file exists for each.
        command: ["bash", "-c", `cd "${root.themesDir}" 2>/dev/null || exit 0; for d in */; do d="\${d%/}"; [ -f "$d/metadata.desktop" ] && echo "$d"; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.themes = text.split("\n").filter(n => n.length > 0).map(name => {
                    const p = root.previewFor(name);
                    return { name: name, previewA: p.a, previewB: p.b };
                });
            }
        }
    }

    FileView {
        id: currentView
        path: "/etc/sddm.conf.d/10-theme.conf"
        printErrors: false
        onLoaded: {
            const m = /^Current=qylock-(.+)$/m.exec(text());
            const n = m ? m[1].trim() : "";
            root.current = n === "nier" ? "nier-automata" : n;   // the first manual install used a short name
        }
        onLoadFailed: root.current = ""
    }

    Process {
        id: applyProc
        stderr: StdioCollector { id: applyErr }
        onExited: (exitCode, exitStatus) => {
            const name = root.busy;
            root.busy = "";
            currentView.reload();
            if (exitCode === 0) {
                Quickshell.execDetached(["notify-send", Translation.tr("Login screen"), Translation.tr("%1 will greet you at the next login").arg(name), "-a", "Shell"]);
            } else if (exitCode === 126 || exitCode === 127) {
                // pkexec: dialog dismissed, or not authorised
                Quickshell.execDetached(["notify-send", Translation.tr("Login screen"), Translation.tr("Not changed (password prompt was cancelled)"), "-a", "Shell"]);
            } else {
                Quickshell.execDetached(["notify-send", Translation.tr("Login screen"), applyErr.text.trim() || Translation.tr("Could not change the login screen"), "-a", "Shell", "-u", "critical"]);
            }
        }
    }
}
