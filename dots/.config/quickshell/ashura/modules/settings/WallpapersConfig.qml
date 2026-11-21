import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Ashura: where wallpapers come from and how they change. Saved in
// ~/.config/ashura/wallpapers.json (services/AshuraWallpapers).
ContentPage {
    forceWidth: true

    // A folder chooser; kdialog is installed with Ashura.
    Process {
        id: chooser
        property string which: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim();
                if (!dir) return;
                if (chooser.which === "normal") AshuraWallpapers.normalFolder = dir;
                else AshuraWallpapers.liveFolder = dir;
            }
        }
    }
    function choose(which, start) {
        chooser.which = which;
        chooser.command = ["kdialog", "--getexistingdirectory", start];
        chooser.running = true;
    }

    component FolderRow: ColumnLayout {
        id: folderRow
        required property string which
        required property string label
        required property string folder
        required property string count
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: folderRow.label
                text: folderRow.folder
                wrapMode: TextEdit.NoWrap
                onEditingFinished: {
                    if (folderRow.which === "normal") AshuraWallpapers.normalFolder = text.trim();
                    else AshuraWallpapers.liveFolder = text.trim();
                }
            }
            RippleButtonWithIcon {
                materialIcon: "folder_open"
                mainText: Translation.tr("Browse")
                onClicked: choose(folderRow.which, folderRow.folder)
            }
        }
        StyledText {
            text: folderRow.count
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    ContentSection {
        icon: "image"
        title: Translation.tr("Wallpaper folders")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("Folders inside these folders count too. Super+W picks a random one, Super+Shift+W opens the picker.")
        }
        FolderRow {
            which: "normal"
            label: Translation.tr("Wallpapers (images)")
            folder: AshuraWallpapers.normalFolder
            count: Translation.tr("%1 images").arg(AshuraWallpapers.images.length)
        }
        FolderRow {
            which: "live"
            label: Translation.tr("Live wallpapers (videos, shaders)")
            folder: AshuraWallpapers.liveFolder
            count: Translation.tr("%1 live wallpapers").arg(AshuraWallpapers.lives.length)
        }
    }

    ContentSection {
        icon: "auto_awesome"
        title: Translation.tr("Transitions")

        ConfigSwitch {
            buttonIcon: "animation"
            text: Translation.tr("Draw the change (outline of the character, or pixel colonies)")
            checked: AshuraWallpapers.transitions
            onCheckedChanged: AshuraWallpapers.transitions = checked
        }
        ConfigSwitch {
            buttonIcon: "grid_on"
            text: Translation.tr("Pixel colonies instead of ink for wallpapers without a character")
            checked: AshuraWallpapers.spreadStyle === "pixels"
            onCheckedChanged: AshuraWallpapers.spreadStyle = checked ? "pixels" : "ink"
        }
        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("A wallpaper's character is cut out once and remembered, which takes about 10 s per new image. Prepare them all now after adding wallpapers, so no change has to wait.")
        }
        RowLayout {
            spacing: 10
            RippleButtonWithIcon {
                materialIcon: AshuraWallpapers.preparing ? "hourglass_top" : "cached"
                mainText: AshuraWallpapers.preparing ? Translation.tr("Preparing…") : Translation.tr("Prepare transitions now")
                enabled: !AshuraWallpapers.preparing
                onClicked: AshuraWallpapers.prepareAll()
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: AshuraWallpapers.prepareLog
                color: Appearance.colors.colSubtext
            }
        }
    }
}
