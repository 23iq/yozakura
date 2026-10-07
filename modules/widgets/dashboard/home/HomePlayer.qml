import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "HomeModel.js" as HomeModel

// "Now playing" on the composed dashboard, built around the art: a large
// Art beside the title, "artist · album" and prev / play / next (play is the
// surface's one primary action), the timeline under them (click to seek;
// the times show only while it is hovered). Where groups are boxes, the
// box takes a faint blurred tint of the art.
Group {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null
    readonly property real length: root.player?.length ?? 0
    readonly property real position: root.player?.position ?? 0
    readonly property url artUrl: root.player?.trackArtUrl ?? ""
    readonly property bool showTimes: seekArea.containsMouse || seekArea.pressed

    Timer {
        running: MprisController.isPlaying && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Item {
        width: parent.width
        implicitHeight: content.implicitHeight

        HomeArtGlow {
            objectName: "artGlow"
            x: -root.padding
            y: -root.padding
            width: parent.width + root.padding * 2
            height: parent.height + root.padding * 2
            radius: Look.groupRadius
            source: root.boxed ? root.artUrl : ""
        }

        Column {
            id: content
            width: parent.width
            spacing: Space.m

            Row {
                width: parent.width
                spacing: Space.l

                Art {
                    id: art
                    objectName: "art"
                    width: Space.controlL + Space.xl
                    height: width
                    icon: Icons.musicNotes
                    source: root.artUrl
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

                    Item {
                        width: 1
                        height: Space.s
                    }

                    Row {
                        x: -Space.s
                        spacing: Space.xs
                        visible: root.hasPlayer

                        IconButton {
                            size: "s"
                            icon: Icons.previous
                            enabled: MprisController.canGoPrevious
                            onClicked: MprisController.previous()
                        }

                        IconButton {
                            objectName: "playButton"
                            size: "s"
                            primary: true
                            icon: MprisController.isPlaying ? Icons.pause : Icons.play
                            enabled: MprisController.canTogglePlaying
                            onClicked: MprisController.togglePlaying()
                        }

                        IconButton {
                            size: "s"
                            icon: Icons.next
                            enabled: MprisController.canGoNext
                            onClicked: MprisController.next()
                        }
                    }
                }
            }

            ProgressLine {
                id: timeline
                objectName: "timeline"
                width: parent.width
                visible: root.hasPlayer
                value: root.length > 0 ? root.position / root.length : 0

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    anchors.topMargin: -Space.s
                    anchors.bottomMargin: -Space.l
                    hoverEnabled: true
                    enabled: root.hasPlayer
                    cursorShape: (root.player?.canSeek ?? false) && root.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: m => {
                        if ((root.player?.canSeek ?? false) && root.length > 0)
                            root.player.position = Math.max(0, Math.min(1, m.x / width)) * root.length;
                    }
                }

                // The times hang under the line (in the group's breathing
                // room) and fade in on hover.
                Item {
                    objectName: "times"
                    y: parent.height + Space.xs
                    width: parent.width
                    height: elapsed.implicitHeight
                    opacity: root.showTimes ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.enter.duration / 2
                        }
                    }

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
        }
    }
}
