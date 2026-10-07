import QtQuick
import qs.config
import qs.modules.services
import qs.modules.components.kit

// notch.mediaStyle "row": Art, title over artist, a small visualizer beside
// previous / play-pause (primary) / next, then the progress line with the
// elapsed and total times.
Column {
    id: root

    required property var player
    property bool revealed: true

    spacing: Space.m

    Item {
        width: parent.width
        height: Math.max(art.height, controls.implicitHeight)

        Art {
            id: art
            objectName: "mediaArt"
            width: Space.controlM + Space.s
            height: width
            anchors.verticalCenter: parent.verticalCenter
            source: root.player?.trackArtUrl ?? ""
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: Space.m
            anchors.right: visualizer.visible ? visualizer.left : controls.left
            anchors.rightMargin: Space.m
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            KitText {
                objectName: "mediaTitle"
                width: parent.width
                role: "body"
                font.weight: Look.activeLabelWeight
                text: root.player?.trackTitle || I18n.t("player.unknown")
            }
            KitText {
                width: parent.width
                role: "secondary"
                text: root.player?.trackArtist || root.player?.identity || ""
            }
        }

        // Small spectrum; a fixed slot so the bars never move the layout
        NotchVisualizer {
            id: visualizer
            anchors.right: controls.left
            anchors.rightMargin: Space.m
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            height: Space.l
            visible: (Config.notch.visualizer ?? true) && CavaService.available
            barCount: 5
            preferredBarWidth: 3
            spacing: 2
            centered: true
            startColor: Type.secondary
            endColor: Type.secondary
            playing: root.player?.isPlaying ?? false
            shown: root.revealed
        }

        MediaTransportControls {
            id: controls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            size: "s"
            spacing: Space.xs
            player: root.player
        }
    }

    MediaSeek {
        width: parent.width
        player: root.player
    }
}
