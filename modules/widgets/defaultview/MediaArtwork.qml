import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// notch.mediaStyle "artwork": a large Art on the left (at least
// notch.expandedArtworkSize, as tall as the text column), and on the right
// the player's name as a small label, the title, artist · album, the
// progress line and shuffle / previous / play (primary) / next, over the
// blurred artwork (AlbumBackdrop).
Item {
    id: root

    required property var player
    property bool revealed: true

    readonly property string source: root.player?.identity || I18n.t("player.unknown_player")
    readonly property bool spotify: /spotify/i.test((root.player?.dbusName ?? "") + (root.player?.identity ?? "") + (root.player?.desktopEntry ?? ""))
    readonly property real artSize: Math.max(Config.notch.expandedArtworkSize ?? 64, column.implicitHeight)

    implicitHeight: Math.max(art.height, column.implicitHeight)

    // The artwork, blurred, tints the group box (over its fill in every
    // language, past the content into the box padding)
    AlbumBackdrop {
        anchors.fill: parent
        anchors.margins: -Math.max(Look.groupPadding, Space.m)
        artwork: root.player?.trackArtUrl ?? ""
        strength: 0.45
        radius: Math.max(Look.groupRadius, Space.controlRadius)
    }

    Art {
        id: art
        objectName: "mediaArt"
        width: root.artSize
        height: root.artSize
        anchors.verticalCenter: parent.verticalCenter
        source: root.player?.trackArtUrl ?? ""
        icon: Icons.player
    }

    Column {
        id: column
        anchors.left: art.right
        anchors.leftMargin: Space.l
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.xs

        Row {
            spacing: Space.xs

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.spotify ? Icons.spotify : Icons.player
                font.family: Icons.font
                font.pixelSize: Type.iconSize("label")
                color: Type.muted
            }
            KitText {
                objectName: "mediaSource"
                anchors.verticalCenter: parent.verticalCenter
                role: "label"
                text: root.source
            }
        }
        KitText {
            objectName: "mediaTitle"
            width: parent.width
            role: "title"
            text: root.player?.trackTitle || I18n.t("player.unknown")
        }
        KitText {
            width: parent.width
            role: "secondary"
            text: [root.player?.trackArtist || "", root.player?.trackAlbum || ""].filter(s => s !== "").join(" · ")
        }
        Item {
            width: 1
            height: Space.xs
        }
        MediaSeek {
            width: parent.width
            player: root.player
        }
        MediaTransportControls {
            anchors.horizontalCenter: parent.horizontalCenter
            size: "s"
            shuffle: true
            player: root.player
        }
    }
}
