import QtQuick
import Quickshell.Widgets
import qs.modules.services
import qs.modules.theme
import qs.modules.desktop.widgets
import qs.modules.widgets.defaultview

// Now playing: album art, title/artist, transport controls and a cava
// spectrum along the bottom (only while playing and on screen).
DesktopWidget {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property string art: hasPlayer ? (player.trackArtUrl ?? "") : ""
    readonly property bool showArt: (options.showArt ?? true) && art !== ""
    readonly property real artSize: height - 2 * pad

    ClippingRectangle {
        id: artBox
        visible: root.showArt
        x: root.pad
        y: root.pad
        width: root.artSize
        height: root.artSize
        radius: Math.min(Styling.radius(0), width / 4)
        color: root.inkFaint

        Image {
            anchors.fill: parent
            source: root.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Math.round(width * 2)
            sourceSize.height: Math.round(height * 2)
        }
    }

    Column {
        id: info
        anchors.left: root.showArt ? artBox.right : parent.left
        anchors.leftMargin: root.pad
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        y: root.pad
        spacing: Math.round(2 * root.k)

        Text {
            width: parent.width
            text: root.hasPlayer ? (root.player.trackTitle || I18n.t("player.unknown_player")) : I18n.t("player.nothing_playing")
            elide: Text.ElideRight
            font.family: root.font
            font.pixelSize: root.px(2)
            font.weight: Font.DemiBold
            color: root.ink
        }
        Text {
            width: parent.width
            text: root.hasPlayer ? (root.player.trackArtist ?? "") : I18n.t("desktop.widgets.media.idle")
            elide: Text.ElideRight
            font.family: root.font
            font.pixelSize: root.px(-1)
            color: root.inkSoft
        }
    }

    Row {
        id: controls
        anchors.left: info.left
        anchors.leftMargin: -Math.round(6 * root.k)
        anchors.top: info.bottom
        anchors.topMargin: Math.round(6 * root.k)
        spacing: Math.round(4 * root.k)
        enabled: root.hasPlayer && !root.editing && !root.preview

        WidgetButton {
            icon: "previous"
            label: I18n.t("island.previous")
            ink: root.ink
            size: Math.round(36 * root.k)
            enabled: MprisController.canGoPrevious
            onClicked: MprisController.previous()
        }
        WidgetButton {
            icon: MprisController.isPlaying ? "pause" : "play"
            label: I18n.t("island.play_pause")
            ink: root.ink
            fill: root.inkFaint
            size: Math.round(40 * root.k)
            enabled: MprisController.canTogglePlaying
            onClicked: MprisController.togglePlaying()
        }
        WidgetButton {
            icon: "next"
            label: I18n.t("island.next")
            ink: root.ink
            size: Math.round(36 * root.k)
            enabled: MprisController.canGoNext
            onClicked: MprisController.next()
        }
    }

    NotchVisualizer {
        anchors.left: info.left
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.pad * 0.75)
        height: Math.max(0, Math.min(Math.round(28 * root.k), parent.height - controls.y - controls.height - root.pad))
        visible: (root.options.visualizer ?? true) && height > 6
        barCount: Math.max(8, Math.min(40, Math.round(width / (9 * root.k))))
        preferredBarWidth: 4 * root.k
        centered: false
        playing: MprisController.isPlaying
        shown: root.active && !root.preview
    }
}
