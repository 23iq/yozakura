import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "HomeModel.js" as HomeModel

// "Now playing" on the composed dashboard: the art beside the title and
// "artist · album", the timeline (click to seek) with its times, then
// prev / play / next where only play is the surface's primary action.
Group {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null
    readonly property real length: root.player?.length ?? 0
    readonly property real position: root.player?.position ?? 0

    label: I18n.t("dashboard.home.now_playing")

    Timer {
        running: MprisController.isPlaying && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Row {
        width: parent.width
        spacing: Space.m

        Art {
            id: art
            width: Space.controlM + Space.l
            height: width
            icon: Icons.musicNotes
            source: root.player?.trackArtUrl ?? ""
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - art.width - parent.spacing
            spacing: Space.xs / 2

            KitText {
                objectName: "title"
                width: parent.width
                text: root.hasPlayer ? (root.player.trackTitle || root.player.identity || "") : I18n.t("player.nothing_playing")
                font.weight: Look.labelWeight
            }

            KitText {
                objectName: "artist"
                width: parent.width
                role: "secondary"
                text: root.hasPlayer ? HomeModel.artistLine(root.player.trackArtist, root.player.trackAlbum) : I18n.t("player.enjoy_silence")
            }
        }
    }

    Column {
        width: parent.width
        spacing: Space.xs
        visible: root.hasPlayer

        ProgressLine {
            objectName: "timeline"
            width: parent.width
            value: root.length > 0 ? root.position / root.length : 0

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -Space.s
                anchors.bottomMargin: -Space.s
                enabled: (root.player?.canSeek ?? false) && root.length > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: m => root.player.position = Math.max(0, Math.min(1, m.x / width)) * root.length
            }
        }

        Item {
            width: parent.width
            height: elapsed.implicitHeight

            KitText {
                id: elapsed
                role: "caption"
                tabular: true
                text: HomeModel.formatTime(root.position)
            }

            KitText {
                anchors.right: parent.right
                role: "caption"
                tabular: true
                text: root.length > 0 ? HomeModel.formatTime(root.length) : "--:--"
            }
        }
    }

    Row {
        x: (parent.width - width) / 2
        spacing: Space.m

        IconButton {
            icon: Icons.previous
            enabled: MprisController.canGoPrevious
            onClicked: MprisController.previous()
        }

        IconButton {
            objectName: "playButton"
            primary: true
            icon: MprisController.isPlaying ? Icons.pause : Icons.play
            enabled: MprisController.canTogglePlaying
            onClicked: MprisController.togglePlaying()
        }

        IconButton {
            icon: Icons.next
            enabled: MprisController.canGoNext
            onClicked: MprisController.next()
        }
    }
}
