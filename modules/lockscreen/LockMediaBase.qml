import QtQuick
import qs.modules.services

// Player state shared by every style's media card (MPRIS active player).
Item {
    id: root

    // Set by LockView.
    property LockView view: null
    // False while the lock screen is animating out, not on screen or in a
    // settings preview; visualizers release cava whenever this is false.
    property bool shown: true
    // lockscreen.showVisualizer (set by LockView).
    property bool visualizerEnabled: true

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && (player.isPlaying ?? false)
    readonly property real length: hasPlayer ? (player.length ?? 0) : 0
    readonly property real position: hasPlayer ? (player.position ?? 0) : 0
    readonly property real progress: Number.isFinite(length) && length > 0 && Number.isFinite(position) ? Math.max(0, Math.min(1, position / length)) : 0
    readonly property string artUrl: hasPlayer ? (player.trackArtUrl ?? "") : ""
    readonly property string title: player?.trackTitle || I18n.t("player.unknown")
    readonly property string artist: player?.trackArtist || player?.identity || ""
    // Gate for a visualizer inside the card.
    readonly property bool visualizerShown: shown && visible && visualizerEnabled

    function toggle() {
        MprisController.togglePlaying();
    }
    function previous() {
        MprisController.previous();
    }
    function next() {
        MprisController.next();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.shown && root.playing
        onTriggered: root.player?.positionChanged()
    }
}
