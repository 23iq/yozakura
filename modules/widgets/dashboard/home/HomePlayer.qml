import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "HomeModel.js" as HomeModel

// "Now playing" on the composed dashboard, built around the art: a large
// Art beside the title, "artist · album" and prev / play / next (play is the
// surface's one primary action), the timeline under them (click to seek;
// the times show only while it is hovered). Where groups are boxes, the
// box takes a faint blurred tint of the art. Fills the height it gets.
Group {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null
    readonly property real length: root.player?.length ?? 0
    readonly property real position: root.player?.position ?? 0
    readonly property url artUrl: root.player?.trackArtUrl ?? ""
    readonly property bool showTimes: seekArea.containsMouse || seekArea.pressed
    // Art at the natural size; given more height (fill), the art grows into
    // it (up to under half the width) and the block stays centered.
    readonly property real baseArt: Space.controlL + Space.xl
    readonly property real lineH: root.hasPlayer ? Space.m + timeline.height : 0
    readonly property real naturalHeight: root.chrome + root.baseArt + root.lineH
    readonly property real innerW: root.width - root.padding * 2
    // Tall enough for the art over the text (a taller host): stack them,
    // centered, so the art can grow instead of leaving bands around it.
    readonly property bool stacked: root.bodyHeight - root.lineH - textBlock.implicitHeight - Space.l > root.innerW * 0.42
    readonly property real artSize: root.stacked ? Math.min(root.innerW * 0.62, root.bodyHeight - root.lineH - textBlock.implicitHeight - Space.l) : Math.max(root.baseArt, Math.min(root.bodyHeight - root.lineH, root.innerW * 0.42))

    fill: true

    Timer {
        running: MprisController.isPlaying && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Item {
        width: parent.width
        height: Math.max(content.implicitHeight, root.bodyHeight)

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
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: Space.m

            Grid {
                width: parent.width
                columns: root.stacked ? 1 : 2
                spacing: Space.l
                horizontalItemAlignment: root.stacked ? Grid.AlignHCenter : Grid.AlignLeft
                verticalItemAlignment: Grid.AlignVCenter

                Art {
                    id: art
                    objectName: "art"
                    width: root.artSize
                    height: width
                    icon: Icons.musicNotes
                    source: root.artUrl
                }

                Column {
                    id: textBlock
                    width: root.stacked ? parent.width : parent.width - art.width - parent.spacing
                    spacing: Space.xs / 2

                    KitText {
                        objectName: "title"
                        width: parent.width
                        horizontalAlignment: root.stacked ? Text.AlignHCenter : Text.AlignLeft
                        text: root.hasPlayer ? (root.player.trackTitle || root.player.identity || "") : I18n.t("player.nothing_playing")
                        font.weight: Look.labelWeight
                    }

                    KitText {
                        objectName: "artist"
                        width: parent.width
                        role: "secondary"
                        horizontalAlignment: root.stacked ? Text.AlignHCenter : Text.AlignLeft
                        text: root.hasPlayer ? HomeModel.artistLine(root.player.trackArtist, root.player.trackAlbum) : I18n.t("player.enjoy_silence")
                    }

                    Item {
                        width: 1
                        height: Space.s
                    }

                    Row {
                        x: root.stacked ? (parent.width - width) / 2 : -Space.s
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
