pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "WidgetFormat.js" as WidgetFormat

// Bento widget "player": the active MPRIS player as album Art (large on a
// tall tile, beside the text otherwise), title and artist, a seekable line
// with the elapsed / total time, and the controls (play is the primary
// action; the shuffle / repeat mode only where it fits). With several
// players the section label names the active one: click it to pick another.
HostWidget {
    id: player

    property bool playersListExpanded: false
    readonly property var mpris: MprisController.activePlayer
    readonly property bool hasActivePlayer: player.mpris !== null
    readonly property bool isPlaying: player.mpris?.playbackState === MprisPlaybackState.Playing
    readonly property real position: player.mpris?.position ?? 0
    readonly property real length: player.mpris?.length ?? 0
    readonly property bool canSeek: player.hasActivePlayer && (player.mpris?.canSeek ?? false)

    // Layout: the art block over the seek line and the controls.
    readonly property real bodyW: group.width - group.padding * 2
    readonly property bool roomy: player.bodyW >= Space.controlS * 2 + Space.controlM * 3 + Space.s * 4
    readonly property real textH: Type.size("body") * 1.4 + Type.size("secondary") * 1.4
    readonly property real restH: seek.height + controls.height + Space.m * 2
    readonly property real topH: group.bodyHeight - player.restH
    readonly property bool wideTile: player.width > player.height * 0.9
    readonly property bool stacked: !player.wideTile && player.topH - player.textH - Space.m >= Space.rowHeight * 1.5
    readonly property real contentH: (player.stacked ? player.artSize + player.textH + Space.m : Math.max(player.textH, player.artSize)) + player.restH
    readonly property real artSize: player.stacked ? Math.min(player.bodyW, player.topH - player.textH - Space.m) : Math.max(Space.controlM, Math.min(player.topH, player.wideTile ? player.bodyW * 0.4 : Space.controlM * 1.4))

    function playerIcon(p) {
        if (!p)
            return Icons.player;
        const names = [(p.dbusName || ""), (p.desktopEntry || ""), (p.identity || "")].join(" ").toLowerCase();
        if (names.includes("spotify"))
            return Icons.spotify;
        if (names.includes("chromium") || names.includes("chrome"))
            return Icons.chromium;
        if (names.includes("firefox"))
            return Icons.firefox;
        if (names.includes("telegram"))
            return Icons.telegram;
        return Icons.player;
    }

    // Position is not notified while playing: poll it while shown.
    Timer {
        running: player.isPlaying && player.visible
        interval: 1000
        repeat: true
        onTriggered: player.mpris?.positionChanged()
    }

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !player.framed
        label: I18n.t("bento.label.player")
        actionText: player.playersListExpanded ? I18n.t("bento.done") : (MprisController.filteredPlayers.length > 1 ? (player.mpris?.identity ?? "") : "")
        onActionTriggered: player.playersListExpanded = !player.playersListExpanded

        // Player picker
        ListView {
            visible: player.playersListExpanded
            width: parent.width
            height: visible ? group.bodyHeight : 0
            clip: true
            spacing: Space.xs
            model: player.playersListExpanded ? MprisController.filteredPlayers : []

            delegate: ListRow {
                id: choice
                required property var modelData
                width: ListView.view.width
                title: choice.modelData?.trackTitle || choice.modelData?.identity || I18n.t("player.unknown_player")
                subtitle: choice.modelData?.identity ?? ""
                selected: choice.modelData === player.mpris
                leading: Component {
                    Text {
                        text: player.playerIcon(choice.modelData)
                        font.family: Icons.font
                        font.pixelSize: Type.iconSize("body")
                        color: Type.secondary
                    }
                }
                onClicked: {
                    MprisController.setActivePlayer(choice.modelData);
                    player.playersListExpanded = false;
                }
            }
        }

        // Centres the stack in a tall tile.
        Item {
            visible: !player.playersListExpanded
            width: 1
            height: Math.max(0, (group.bodyHeight - player.contentH) / 2 - Space.m)
        }

        Art {
            visible: !player.playersListExpanded && player.stacked
            anchors.horizontalCenter: parent.horizontalCenter
            width: player.artSize
            height: player.artSize
            source: player.mpris?.trackArtUrl ?? ""
            icon: Icons.musicNotes
        }

        Row {
            visible: !player.playersListExpanded
            width: parent.width
            height: player.stacked ? player.textH : Math.max(player.textH, player.artSize)
            spacing: Space.m

            Art {
                visible: !player.stacked
                anchors.verticalCenter: parent.verticalCenter
                width: player.artSize
                height: player.artSize
                source: player.mpris?.trackArtUrl ?? ""
                icon: Icons.musicNotes
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (player.stacked ? 0 : player.artSize + Space.m)
                spacing: 2

                KitText {
                    objectName: "playerTitle"
                    width: parent.width
                    horizontalAlignment: player.stacked ? Text.AlignHCenter : Text.AlignLeft
                    role: "body"
                    font.weight: Font.Medium
                    text: player.hasActivePlayer ? (player.mpris?.trackTitle ?? "") : I18n.t("player.nothing_playing")
                }
                KitText {
                    width: parent.width
                    horizontalAlignment: player.stacked ? Text.AlignHCenter : Text.AlignLeft
                    role: "secondary"
                    text: player.hasActivePlayer ? [player.mpris?.trackArtist ?? "", player.mpris?.trackAlbum ?? ""].filter(s => s !== "").join(" · ") : I18n.t("player.enjoy_silence")
                }
            }
        }

        Column {
            id: seek
            visible: !player.playersListExpanded
            width: parent.width
            spacing: Space.xs

            LineSlider {
                id: seekLine
                width: parent.width
                height: Space.m
                enabled: player.canSeek
                onMoved: v => {
                    if (player.canSeek)
                        player.mpris.position = v * player.length;
                }
            }
            Binding {
                target: seekLine
                property: "value"
                value: player.length > 0 ? player.position / player.length : 0
                when: !seekLine.pressed
            }
            Item {
                width: parent.width
                height: elapsed.implicitHeight

                KitText {
                    id: elapsed
                    role: "caption"
                    tabular: true
                    text: player.hasActivePlayer ? WidgetFormat.mediaTime(player.position) : "-:--"
                }
                KitText {
                    anchors.right: parent.right
                    role: "caption"
                    tabular: true
                    text: player.hasActivePlayer ? WidgetFormat.mediaTime(player.length) : "-:--"
                }
            }
        }

        Row {
            id: controls
            visible: !player.playersListExpanded
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: player.roomy ? Space.s : 0
            enabled: player.hasActivePlayer

            IconButton {
                visible: player.roomy
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                icon: MprisController.hasShuffle ? Icons.shuffle : (MprisController.loopState === MprisLoopState.Track ? Icons.repeatOnce : (MprisController.loopState === MprisLoopState.Playlist ? Icons.repeat : Icons.shuffle))
                active: MprisController.hasShuffle || MprisController.loopState !== MprisLoopState.None
                enabled: MprisController.shuffleSupported || MprisController.loopSupported
                onClicked: {
                    if (MprisController.hasShuffle) {
                        MprisController.setShuffle(false);
                        MprisController.setLoopState(MprisLoopState.Playlist);
                    } else if (MprisController.loopState === MprisLoopState.Playlist) {
                        MprisController.setLoopState(MprisLoopState.Track);
                    } else if (MprisController.loopState === MprisLoopState.Track) {
                        MprisController.setLoopState(MprisLoopState.None);
                    } else {
                        MprisController.setShuffle(true);
                    }
                }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: player.roomy ? "m" : "s"
                icon: Icons.previous
                enabled: MprisController.canGoPrevious
                onClicked: MprisController.previous()
            }
            IconButton {
                objectName: "playerPlay"
                anchors.verticalCenter: parent.verticalCenter
                size: player.roomy ? "m" : "s"
                primary: true
                icon: player.isPlaying ? Icons.pause : Icons.play
                onClicked: MprisController.togglePlaying()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: player.roomy ? "m" : "s"
                icon: Icons.next
                enabled: MprisController.canGoNext
                onClicked: MprisController.next()
            }
            IconButton {
                visible: player.roomy
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                icon: player.playerIcon(player.mpris)
                onClicked: MprisController.cyclePlayer(1)
            }
        }
    }
}
