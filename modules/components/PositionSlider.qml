import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.modules.components.kit

// The seek bar of a media player: the kit LineSlider with the shell's wavy
// fill while playing (performance.wavyLine) and its playhead knob always
// shown. It follows the player's
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
    alwaysShowKnob: true
    wheelEnabled: false

    // The dragged fraction, kept apart from `value` (the Binding below puts
    // the player position back into it on release).
    property real dragged: -1

    onMoved: v => root.dragged = v
    onPressedChanged: {
        if (root.pressed)
            return;
        if (root.dragged >= 0 && root.player && root.player.canSeek && root.length > 0)
            root.player.position = root.dragged * root.length;
        root.dragged = -1;
    }

    Binding {
        target: root
        property: "value"
        value: root.length > 0 ? Math.min(1, (root.player?.position ?? 0) / root.length) : 0
        when: !root.pressed
    }
}
