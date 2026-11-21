import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Ashura: the desktop clock (modules/ashura/desktopClock) and the dashboard's
// pictures (modules/ashura/bar/DashboardPanel). Saved in
// ~/.config/ashura/settings.json (services/AshuraSettings).
ContentPage {
    forceWidth: true

    // A gif chooser; kdialog is installed with Ashura.
    Process {
        id: chooser
        stdout: StdioCollector {
            onStreamFinished: {
                const file = text.trim();
                if (file) AshuraSettings.dashboardGif = file;
            }
        }
    }

    ContentSection {
        icon: "schedule"
        title: Translation.tr("Desktop clock")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Show the clock on the desktop")
            checked: AshuraSettings.clockEnabled
            onCheckedChanged: AshuraSettings.clockEnabled = checked
        }
        ConfigRow {
            enabled: AshuraSettings.clockEnabled
            uniform: true
            ConfigSwitch {
                buttonIcon: "nest_clock_farsight_digital"
                text: Translation.tr("24 hour time")
                checked: AshuraSettings.clock24h
                onCheckedChanged: AshuraSettings.clock24h = checked
            }
            ConfigSwitch {
                buttonIcon: "calendar_today"
                text: Translation.tr("Show the date")
                checked: AshuraSettings.clockShowDate
                onCheckedChanged: AshuraSettings.clockShowDate = checked
            }
        }
        ConfigSpinBox {
            enabled: AshuraSettings.clockEnabled
            icon: "format_size"
            text: Translation.tr("Size (px)")
            value: AshuraSettings.clockSize
            from: 48
            to: 200
            stepSize: 4
            onValueChanged: AshuraSettings.clockSize = value
        }
        ContentSubsection {
            enabled: AshuraSettings.clockEnabled
            title: Translation.tr("Where it sits")
            tooltip: Translation.tr("Automatic finds the quietest corner of each wallpaper and picks a readable colour for it. A fixed corner keeps that colour, so it can be harder to read on busy wallpapers.")
            ConfigSelectionArray {
                currentValue: AshuraSettings.clockPlacement
                onSelected: newValue => AshuraSettings.clockPlacement = newValue
                options: [
                    { displayName: Translation.tr("Automatic"), icon: "auto_awesome", value: "auto" },
                    { displayName: Translation.tr("Top left"), icon: "north_west", value: "top-left" },
                    { displayName: Translation.tr("Top right"), icon: "north_east", value: "top-right" },
                    { displayName: Translation.tr("Bottom left"), icon: "south_west", value: "bottom-left" },
                    { displayName: Translation.tr("Bottom right"), icon: "south_east", value: "bottom-right" }
                ]
            }
        }
    }

    ContentSection {
        icon: "dashboard"
        title: Translation.tr("Dashboard")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("The picture beside your name on the dashboard's first tab. Any gif or image works.")
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Dashboard picture (empty: the bundled gif)")
                text: AshuraSettings.dashboardGif
                wrapMode: TextEdit.NoWrap
                onEditingFinished: AshuraSettings.dashboardGif = text.trim()
            }
            RippleButtonWithIcon {
                materialIcon: "image_search"
                mainText: Translation.tr("Browse")
                onClicked: {
                    chooser.command = ["kdialog", "--getopenfilename",
                        AshuraSettings.dashboardGif || `${Directories.home.replace("file://", "")}/Pictures`,
                        "image/gif image/png image/jpeg image/webp"];
                    chooser.running = true;
                }
            }
            RippleButtonWithIcon {
                materialIcon: "restart_alt"
                mainText: Translation.tr("Default")
                enabled: AshuraSettings.dashboardGif !== ""
                onClicked: AshuraSettings.dashboardGif = ""
            }
        }
        ConfigSwitch {
            buttonIcon: "pets"
            text: Translation.tr("Bongo cat on the Dashboard tab (drums while music plays)")
            checked: AshuraSettings.dashboardBongoCat
            onCheckedChanged: AshuraSettings.dashboardBongoCat = checked
        }
    }
}
