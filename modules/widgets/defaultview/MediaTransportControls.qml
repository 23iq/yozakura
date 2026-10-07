import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.modules.components.kit

// Transport of the notch media panel: [shuffle] / previous / play-pause
// (the panel's one primary action) / next as kit IconButtons.
Row {
    id: root

    required property var player
    // Show the shuffle toggle (artwork style; only when the player has one)
    property bool shuffle: false
    property string size: "m"

    spacing: Space.s

    IconButton {
        objectName: "mediaShuffle"
        size: root.size
        visible: root.shuffle && MprisController.shuffleSupported
        active: MprisController.hasShuffle
        icon: Icons.shuffle
        Accessible.name: I18n.t("island.shuffle")
        onClicked: MprisController.setShuffle(!MprisController.hasShuffle)
    }
    IconButton {
        objectName: "mediaPrevious"
        size: root.size
        icon: Icons.previous
        enabled: root.player?.canGoPrevious ?? false
        Accessible.name: I18n.t("island.previous")
        onClicked: root.player?.previous()
    }
    IconButton {
        objectName: "mediaPlayPause"
        size: root.size
        primary: true
        icon: root.player?.isPlaying ? Icons.pause : Icons.play
        enabled: root.player?.canTogglePlaying ?? false
        Accessible.name: I18n.t("island.play_pause")
        onClicked: root.player?.togglePlaying()
    }
    IconButton {
        objectName: "mediaNext"
        size: root.size
        icon: Icons.next
        enabled: root.player?.canGoNext ?? false
        Accessible.name: I18n.t("island.next")
        onClicked: root.player?.next()
    }
}
