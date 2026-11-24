import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

// Ashura: the music bar that rises from the bottom edge (EdgeHovers): cover,
// title and artist, what plays next (Spotify, through MusicExtras), a heart,
// shuffle / previous / play-pause / next / repeat, and a progress bar you can
// drag to seek. Scroll on the bar to seek 5 s; Ctrl+scroll for the volume
// (Super+scroll belongs to the workspaces).
Item {
    id: root
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null
    implicitWidth: 760
    implicitHeight: root.hasPlayer ? 116 : 64

    // The heart and the next song are asked for only while the bar is up.
    onVisibleChanged: MusicExtras.wanted = root.visible
    Component.onCompleted: MusicExtras.wanted = root.visible

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const up = event.angleDelta.y > 0 || event.pixelDelta.y > 0;
            if (event.modifiers & Qt.ControlModifier) {
                const a = Audio.sink?.audio;
                if (a) a.volume = Math.max(0, Math.min(2, a.volume + (up ? 0.05 : -0.05)));
            } else if (root.player?.canSeek) {
                root.player.position = Math.max(0, Math.min(root.player.length, root.player.position + (up ? 5 : -5)));
            }
        }
    }

    // The position only updates when asked; ask while the bar is up.
    Timer {
        interval: 500; repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player?.positionChanged()
    }

    RowLayout {
        visible: !root.hasPlayer
        anchors.centerIn: parent
        spacing: 8
        MaterialSymbol { text: "music_off"; iconSize: Appearance.font.pixelSize.huge; color: Appearance.colors.colSubtext }
        StyledText { text: Translation.tr("Nothing playing"); color: Appearance.colors.colSubtext }
    }

    ColumnLayout {
        visible: root.hasPlayer
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 14
        anchors.bottomMargin: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {   // cover
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer
                clip: true
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "music_note"
                    iconSize: 28
                    color: Appearance.colors.colOnSecondaryContainer
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || Translation.tr("Unknown track")
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.player?.trackArtist ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                StyledText {   // what plays next, when the player shares it
                    Layout.fillWidth: true
                    visible: MusicExtras.nextTitle !== ""
                    elide: Text.ElideRight
                    text: Translation.tr("Next: %1").arg(MusicExtras.nextArtist !== ""
                        ? `${MusicExtras.nextTitle} · ${MusicExtras.nextArtist}` : MusicExtras.nextTitle)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colPrimary
                }
            }

            // Like: the Spotify library for Spotify songs (when signed in),
            // Ashura's own list for everything else.
            RippleButton {
                implicitWidth: 38; implicitHeight: 38
                buttonRadius: 19
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: MusicExtras.toggleLike()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "favorite"
                    fill: MusicExtras.liked ? 1 : 0
                    iconSize: Appearance.font.pixelSize.huge
                    color: MusicExtras.liked ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                }
                StyledToolTip { text: MusicExtras.useSpotifyLibrary ? Translation.tr("Like on Spotify") : Translation.tr("Like (kept in Ashura)") }
            }

            RowLayout {
                spacing: 4
                // Shuffle, only when the player supports it.
                RippleButton {
                    visible: MprisController.shuffleSupported
                    implicitWidth: 32; implicitHeight: 32
                    buttonRadius: 16
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: MprisController.setShuffle(!MprisController.hasShuffle)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "shuffle"
                        iconSize: Appearance.font.pixelSize.larger
                        color: MprisController.hasShuffle ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                }
                Repeater {
                    model: [
                        { icon: "skip_previous", big: false, act: () => root.player?.previous() },
                        { icon: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow", big: true, act: () => root.player?.togglePlaying() },
                        { icon: "skip_next", big: false, act: () => root.player?.next() }
                    ]
                    delegate: RippleButton {
                        required property var modelData
                        implicitWidth: modelData.big ? 48 : 38
                        implicitHeight: modelData.big ? 48 : 38
                        buttonRadius: modelData.big ? Appearance.rounding.normal : 19
                        colBackground: modelData.big ? Appearance.colors.colPrimary : "transparent"
                        colBackgroundHover: modelData.big ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer1Hover
                        onClicked: modelData.act()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: modelData.icon
                            fill: 1
                            iconSize: modelData.big ? 28 : Appearance.font.pixelSize.huge
                            color: modelData.big ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                        }
                    }
                }
                // Repeat: off, the whole list, this song.
                RippleButton {
                    visible: MprisController.loopSupported
                    implicitWidth: 32; implicitHeight: 32
                    buttonRadius: 16
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: MprisController.setLoopState(MprisController.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                        : MprisController.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: MprisController.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                        iconSize: Appearance.font.pixelSize.larger
                        color: MprisController.loopState === MprisLoopState.None ? Appearance.colors.colSubtext : Appearance.colors.colPrimary
                    }
                }
            }
        }

        RowLayout {   // progress
            Layout.fillWidth: true
            spacing: 10
            StyledText {
                text: StringUtils.friendlyTimeForSeconds(root.player?.position ?? 0)
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.family: Appearance.font.family.numbers
                color: Appearance.colors.colSubtext
            }
            StyledSlider {
                Layout.fillWidth: true
                configuration: StyledSlider.Configuration.XS
                enabled: root.player?.canSeek ?? false
                from: 0
                to: 1
                value: (root.player?.length ?? 0) > 0 ? (root.player.position / root.player.length) : 0
                tooltipContent: StringUtils.friendlyTimeForSeconds(value * (root.player?.length ?? 0))
                onMoved: if (root.player?.canSeek) root.player.position = value * root.player.length
            }
            StyledText {
                text: StringUtils.friendlyTimeForSeconds(root.player?.length ?? 0)
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.family: Appearance.font.family.numbers
                color: Appearance.colors.colSubtext
            }
        }
    }
}
