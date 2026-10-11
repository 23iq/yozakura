import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "../home/HomeModel.js" as HomeModel

// The playing hero of the stage home: a large cover with a soft shadow on
// the left (as tall as the hero, up to about half its width; cross-fades on
// track change). Beside it, from the top: the source as a label, the title
// large and bold (up to two lines), the artist and the album (when short
// the source and the album drop, the title keeps one line); at the bottom
// the wavy timeline (PositionSlider: drag or click to seek, the wave follows
// performance.wavyLine) with the times under its ends, and the transport:
// previous / next quiet, play a huge round primary action.
Item {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property real length: root.player?.length ?? 0
    readonly property real position: root.player?.position ?? 0
    // Play grows into a hero action when there is room for it.
    readonly property bool roomy: root.height >= Space.controlL * 4
    readonly property real controlsH: root.roomy ? Space.controlXL * 0.8 : Space.controlL
    readonly property real artSize: Math.max(Space.controlL, Math.min(root.height, root.width * 0.46))
    readonly property real naturalHeight: Space.controlXL * 2
    // Short: the album and the source drop, the title keeps one line.
    readonly property bool tight: root.height < Space.controlXL * 2 + Space.xl

    Timer {
        running: MprisController.isPlaying && root.visible
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    StageArt {
        id: art
        anchors.verticalCenter: parent.verticalCenter
        width: root.artSize
        height: width
        source: root.player?.trackArtUrl ?? ""
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colors.shadow
            shadowOpacity: 0.55
            shadowBlur: 1
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
            anchors.bottom: timeline.top
            anchors.bottomMargin: Space.m
            spacing: Space.xs

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
                font.pixelSize: Math.round(Type.size("title") * 1.45)
                font.weight: Font.Bold
                lineHeight: 0.95
                text: root.player ? (root.player.trackTitle || root.player.identity || "") : ""
                wrapMode: Text.Wrap
                maximumLineCount: root.tight ? 1 : 2
                elide: Text.ElideRight
            }

            KitText {
                objectName: "artist"
                width: parent.width
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

        // The wavy timeline with the times under its ends.
        Item {
            id: timeline
            objectName: "timeline"
            anchors.bottom: controls.top
            anchors.bottomMargin: Space.s
            width: parent.width
            height: Space.l + times.height

            PositionSlider {
                objectName: "seek"
                width: parent.width
                height: Space.l
                player: root.player
                useCustomColors: true
                customProgressColor: Type.progress
                customBackgroundColor: Type.track
            }

            Item {
                id: times
                anchors.bottom: parent.bottom
                width: parent.width
                height: elapsed.implicitHeight

                KitText {
                    id: elapsed
                    objectName: "elapsed"
                    role: "caption"
                    color: Type.secondary
                    tabular: true
                    text: HomeModel.formatTime(root.position)
                }

                KitText {
                    anchors.right: parent.right
                    role: "caption"
                    color: Type.secondary
                    tabular: true
                    text: root.length > 0 ? HomeModel.formatTime(root.length) : "--:--"
                }
            }
        }

        Row {
            id: controls
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: root.controlsH
            spacing: Space.l

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.previous
                enabled: MprisController.canGoPrevious
                onClicked: MprisController.previous()
            }

            IconButton {
                objectName: "playButton"
                anchors.verticalCenter: parent.verticalCenter
                size: root.roomy ? "xl" : "l"
                width: root.controlsH
                height: width
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
