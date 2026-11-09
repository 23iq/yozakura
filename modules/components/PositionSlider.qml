import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.modules.components.kit

// The seek bar of a media player: the kit LineSlider with the shell's wavy
// fill while playing (performance.wavyLine). It follows the player's
// position except while dragged; the seek happens on release, the wheel
// is left to the surface under it.
LineSlider {
    id: root

    required property var player
    readonly property bool isPlaying: root.player?.playbackState === MprisPlaybackState.Playing
    readonly property real length: root.player?.length ?? 0

    implicitHeight: Space.l
    wavy: Config.performance ? Config.performance.wavyLine !== false : true
    playing: root.isPlaying
    wheelEnabled: false

    onPressedChanged: {
        if (!root.pressed && root.player && root.player.canSeek && root.length > 0)
            root.player.position = root.value * root.length;
    }

    Binding {
        target: root
        property: "value"
        value: root.length > 0 ? Math.min(1, (root.player?.position ?? 0) / root.length) : 0
        when: !root.pressed
    }
}
