import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../home/HomeModel.js" as HomeModel

// The playing hero of the stage home: a large cover (cross-fades on track
// change) with the source as a label over the title (up to two lines),
// artist and album along its bottom edge; under them the timeline
// (click to seek) with the elapsed / total times at its ends and the
// transport in the middle, play as the surface's one primary action.
// Fills the size it is given; the cover takes the free height.
Item {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property real length: root.player?.length ?? 0
    readonly property real position: root.player?.position ?? 0
    // Play grows into a hero action when there is room for it.
    readonly property bool roomy: root.height >= Space.controlL * 4
    readonly property real controlsH: root.roomy ? Space.controlL : Space.controlM
    readonly property real bottomH: timeline.height + Space.m + root.controlsH
    readonly property real artSize: Math.max(Space.controlL, Math.min(root.height - root.bottomH - Space.l, root.width * 0.48))
    readonly property real naturalHeight: Space.controlL + Space.xl + Space.l + root.bottomH

    Timer {
        running: MprisController.isPlaying && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    StageArt {
        id: art
        width: root.artSize
        height: width
        source: root.player?.trackArtUrl ?? ""
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: Space.l
        anchors.right: parent.right
        anchors.bottom: art.bottom
        spacing: Space.xs

        KitText {
            objectName: "source"
            width: parent.width
            role: "label"
            // Over the tint the muted ink would sink: secondary instead.
            color: Type.secondary
            text: root.player?.identity ?? ""
            visible: text !== ""
            elide: Text.ElideRight
        }

        KitText {
            objectName: "title"
            width: parent.width
            role: "title"
            text: root.player ? (root.player.trackTitle || root.player.identity || "") : ""
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        KitText {
            objectName: "artist"
            width: parent.width
            text: root.player?.trackArtist ?? ""
            visible: text !== ""
            elide: Text.ElideRight
        }

        KitText {
            objectName: "album"
            width: parent.width
            role: "caption"
            color: Type.secondary
            text: root.player?.trackAlbum ?? ""
            visible: text !== ""
            elide: Text.ElideRight
        }
    }

    ProgressLine {
        id: timeline
        objectName: "timeline"
        anchors.bottom: controls.top
        anchors.bottomMargin: Space.m
        width: parent.width
        value: root.length > 0 ? root.position / root.length : 0

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -Space.s
            anchors.bottomMargin: -Space.s
            cursorShape: (root.player?.canSeek ?? false) && root.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: m => {
                if ((root.player?.canSeek ?? false) && root.length > 0)
                    root.player.position = Math.max(0, Math.min(1, m.x / width)) * root.length;
            }
        }
    }

    Item {
        id: controls
        anchors.bottom: parent.bottom
        width: parent.width
        height: root.controlsH

        KitText {
            objectName: "elapsed"
            anchors.left: parent.left
            anchors.top: parent.top
            role: "caption"
            color: Type.secondary
            tabular: true
            text: HomeModel.formatTime(root.position)
        }

        KitText {
            anchors.right: parent.right
            anchors.top: parent.top
            role: "caption"
            color: Type.secondary
            tabular: true
            text: root.length > 0 ? HomeModel.formatTime(root.length) : "--:--"
        }

        Row {
            anchors.centerIn: parent
            spacing: Space.m

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.previous
                enabled: MprisController.canGoPrevious
                onClicked: MprisController.previous()
            }

            IconButton {
                objectName: "playButton"
                anchors.verticalCenter: parent.verticalCenter
                size: root.roomy ? "l" : "m"
                primary: true
                icon: MprisController.isPlaying ? Icons.pause : Icons.play
                enabled: MprisController.canTogglePlaying
                onClicked: MprisController.togglePlaying()
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.next
                enabled: MprisController.canGoNext
                onClicked: MprisController.next()
            }
        }
    }
}
