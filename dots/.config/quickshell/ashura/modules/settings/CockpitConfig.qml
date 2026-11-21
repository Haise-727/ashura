import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Ashura: which repos have a cockpit, and the URLs each one opens. The list
// lives in devpit (`devpit cockpit ...`); this page only calls it. Opening and
// switching cockpits stays in the shell (Super+Space, Super+D).
ContentPage {
    id: page
    forceWidth: true

    property var cockpits: []
    property var candidates: []
    property string error: ""
    property bool busy: listProc.running || candProc.running || jobProc.running

    // devpit is usually on PATH; a session started by the display manager may
    // not have ~/.local/bin on it.
    function devpit(args) {
        return ["bash", "-c", 'if command -v devpit >/dev/null; then exec devpit "$@"; else exec "$HOME/.local/bin/devpit" "$@"; fi', "devpit"].concat(args);
    }
    function parse(text) {
        try {
            const d = JSON.parse(text);
            if (d.error) { page.error = d.error; return null; }
            page.error = "";
            return d;
        } catch (e) {
            page.error = Translation.tr("devpit gave no answer. Is it installed? (git submodule update --init in the Ashura repo)");
            return null;
        }
    }
    function reload() {
        listProc.running = true;
        candProc.running = true;
    }
    function run(args) {
        jobProc.command = page.devpit(args.concat(["--json"]));
        jobProc.running = true;
    }
    Component.onCompleted: reload()

    Process {
        id: listProc
        command: page.devpit(["cockpit", "list", "--json"])
        stdout: StdioCollector {
            onStreamFinished: { const d = page.parse(text); if (d) page.cockpits = d.cockpits; }
        }
    }
    Process {
        id: candProc
        command: page.devpit(["cockpit", "candidates", "--json"])
        stdout: StdioCollector {
            onStreamFinished: { const d = page.parse(text); if (d) page.candidates = d.candidates; }
        }
    }
    Process {
        id: jobProc
        stdout: StdioCollector {
            onStreamFinished: { page.parse(text); page.reload(); }
        }
    }

    ContentSection {
        icon: "rocket_launch"
        title: Translation.tr("Cockpits")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("A cockpit is a repo with a space of its own (workspaces 101 to 110). Opening one starts VS Code and a terminal in the repo, plus a browser window with its URLs. Super+Space picks one, Super+D goes in and out, Ctrl+Super+D closes the repo on stage.")
        }
        StyledText {
            visible: page.error !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colError
            text: page.error
        }
        StyledText {
            visible: page.cockpits.length === 0 && page.error === "" && !page.busy
            color: Appearance.colors.colSubtext
            text: Translation.tr("No cockpits yet. Add a repo below.")
        }

        Repeater {
            model: page.cockpits
            delegate: Rectangle {
                id: card
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: cardCol.implicitHeight + 20
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: cardCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: card.modelData.exists ? "folder_code" : "folder_off"
                            iconSize: Appearance.font.pixelSize.huge
                            color: card.modelData.exists ? Appearance.colors.colPrimary : Appearance.colors.colError
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                text: card.modelData.name
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                text: card.modelData.exists
                                    ? `${card.modelData.path}  ·  ${card.modelData.git?.branch ?? ""}`
                                    : Translation.tr("%1 is gone").arg(card.modelData.path)
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "delete"
                            mainText: Translation.tr("Remove")
                            enabled: !page.busy
                            onClicked: {
                                // Close its windows first, as the shell does, so nothing
                                // stays filed under a cockpit that no longer exists.
                                Quickshell.execDetached(["hyprctl", "eval", `ashura_cockpit.close(${JSON.stringify(card.modelData.id)})`]);
                                page.run(["cockpit", "remove", card.modelData.id]);
                            }
                        }
                    }
                    MaterialTextArea {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("URLs to open with it, separated by spaces")
                        text: (card.modelData.urls ?? []).join(" ")
                        wrapMode: TextEdit.Wrap
                        onEditingFinished: {
                            const urls = text.split(/\s+/).filter(u => u.length > 0);
                            if (urls.join(" ") === (card.modelData.urls ?? []).join(" ")) return;
                            page.run(["cockpit", "urls", card.modelData.id].concat(urls));
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "add_circle"
        title: Translation.tr("Add a repo")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("Repos devpit found on this machine. Where it looks is set in ~/.config/devpit/config.json.")
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: page.candidates.filter(c => !page.cockpits.some(k => k.path === c.path))
                delegate: RippleButtonWithIcon {
                    required property var modelData
                    materialIcon: "add"
                    mainText: modelData.name
                    enabled: !page.busy
                    onClicked: page.run(["cockpit", "add", modelData.path])
                    StyledToolTip { text: modelData.path }
                }
            }
        }
    }
}
