import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "../home/HomeModel.js" as HomeModel

// The playing hero of the stage home, horizontal and compact: the cover
// with a soft shadow on the left (as tall as the hero, up to 40% of its
// width; cross-fades on track change). Beside it the source as a label,
// the title bold (two lines, one when short), the artist and the album; at the
// bottom the wavy timeline (PositionSlider: drag or click to seek) and one
// transport row: elapsed time, previous, play (the surface's one solid
// accent action), next, length. A new track slides the text in; play /
// pause pops its glyph.
Item {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property real length: root.player?.length ?? 0
    readonly property real position: root.player?.position ?? 0
    readonly property real naturalHeight: Space.controlXL + Space.xxl + Space.xl
    // Play is a hero action at the natural height, smaller below it.
    readonly property bool roomy: root.height >= root.naturalHeight - 1
    readonly property real playSize: root.roomy ? Space.controlL - Space.xs : Space.controlM + Space.xs
    readonly property real artSize: Math.max(Space.controlL, Math.min(root.height, root.width * 0.4))
    // Short: the source drops and the title keeps one line.
    readonly property bool tight: root.height < root.naturalHeight - Space.s
    readonly property string title: root.player ? (root.player.trackTitle || root.player.identity || "") : ""
    readonly property Item focusTarget: play
    // Track change: 0 -> 1 slides the text in.
    property real enterT: 1
    // The cover stays while the player fades out (no placeholder flash).
    readonly property url liveArt: root.player?.trackArtUrl ?? ""
    property url keptArt: ""
    onLiveArtChanged: if (root.player)
        root.keptArt = root.liveArt
    Component.onCompleted: root.keptArt = root.liveArt

    onTitleChanged: if (Motion.glide.duration > 0 && root.visible)
        textIn.restart()

    Connections {
        target: MprisController
        function onIsPlayingChanged() {
            play.pulse();
        }
    }

    Timer {
        running: MprisController.isPlaying && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    NumberAnimation {
        id: textIn
        target: root
        property: "enterT"
        from: 0
        to: 1
        duration: Motion.glide.duration
        easing.type: Motion.glide.easing
    }

    StageArt {
        id: art
        anchors.verticalCenter: parent.verticalCenter
        width: root.artSize
        height: width
        source: root.keptArt
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colors.shadow
            shadowOpacity: 0.5
            shadowBlur: 0.8
            shadowVerticalOffset: Space.xs
            autoPaddingEnabled: true
        }
    }

    Item {
        id: side
        anchors.left: art.right
        anchors.leftMargin: Space.l
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Column {
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: root.tight ? 0 : Space.xs
            spacing: Space.xs / 2
            opacity: root.enterT
            transform: Translate {
                x: (1 - root.enterT) * Space.l
            }

            KitText {
                objectName: "source"
                width: parent.width
                role: "label"
                // Over the flood the muted ink would sink: secondary instead.
                color: Type.secondary
                text: root.player?.identity ?? ""
                visible: text !== "" && !root.tight
                elide: Text.ElideRight
            }

            KitText {
                objectName: "title"
                width: parent.width
                role: "title"
                font.pixelSize: Math.round(Type.size("title") * 1.3)
                font.weight: Font.Bold
                lineHeight: 0.95
                text: root.title
                wrapMode: Text.Wrap
                maximumLineCount: root.tight ? 1 : 2
                elide: Text.ElideRight
            }

            KitText {
                objectName: "artist"
                width: parent.width
                role: "secondary"
                font.weight: Font.DemiBold
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
                visible: text !== "" && !root.tight
                elide: Text.ElideRight
            }
        }

        PositionSlider {
            objectName: "seek"
            anchors.bottom: transport.top
            anchors.bottomMargin: Space.xs
            width: parent.width
            height: Space.l
            player: root.player
            useCustomColors: true
            customProgressColor: Type.progress
            customBackgroundColor: Type.track
        }

        // Elapsed | previous, play, next | length.
        Item {
            id: transport
            objectName: "transport"
            anchors.bottom: parent.bottom
            width: parent.width
            height: root.playSize

            KitText {
                objectName: "elapsed"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                color: Type.secondary
                tabular: true
                text: HomeModel.formatTime(root.position)
            }

            Row {
                anchors.centerIn: parent
                spacing: Space.s

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    objectName: "prevButton"
                    icon: Icons.previous
                    focusable: true
                    enabled: MprisController.canGoPrevious
                    onClicked: MprisController.previous()
                }

                IconButton {
                    id: play
                    objectName: "playButton"
                    anchors.verticalCenter: parent.verticalCenter
                    size: "l"
                    width: root.playSize
                    height: width
                    primary: true
                    focusable: true
                    icon: MprisController.isPlaying ? Icons.pause : Icons.play
                    enabled: MprisController.canTogglePlaying
                    onClicked: MprisController.togglePlaying()
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    objectName: "nextButton"
                    icon: Icons.next
                    focusable: true
                    enabled: MprisController.canGoNext
                    onClicked: MprisController.next()
                }
            }

            KitText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                color: Type.secondary
                tabular: true
                text: root.length > 0 ? HomeModel.formatTime(root.length) : "--:--"
            }
        }
    }
}
