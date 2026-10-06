import QtQuick
import qs.modules.components.kit
import "IslandMedia.js" as Media

// Playback position of the notch media panel: a ProgressLine (click or drag
// to seek when the player can) over the elapsed and total times.
Column {
    id: root

    required property var player
    readonly property real length: root.player?.length ?? 0
    readonly property real position: root.player?.position ?? 0
    readonly property bool hasDuration: Number.isFinite(root.length) && root.length > 0
    readonly property bool seekable: Media.canSeek(root.player)
    readonly property real fraction: root.hasDuration && Number.isFinite(root.position) ? Math.max(0, Math.min(1, root.position / root.length)) : 0

    spacing: Space.xs

    // MPRIS does not notify position changes: poll while playing
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player?.positionChanged()
    }

    Item {
        width: parent.width
        height: Space.s

        ProgressLine {
            objectName: "mediaProgress"
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            value: root.fraction
        }
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -Space.xs
            anchors.bottomMargin: -Space.xs
            enabled: root.seekable
            cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
            function seek(x: real) {
                root.player.position = Math.max(0, Math.min(1, x / width)) * root.length;
            }
            onPressed: m => seek(m.x)
            onPositionChanged: m => {
                if (pressed)
                    seek(m.x);
            }
        }
    }

    Item {
        width: parent.width
        height: elapsed.implicitHeight

        KitText {
            id: elapsed
            anchors.left: parent.left
            role: "caption"
            tabular: true
            text: Media.formatTime(root.position)
        }
        KitText {
            anchors.right: parent.right
            role: "caption"
            tabular: true
            text: root.hasDuration ? Media.formatTime(root.length) : "—"
        }
    }
}
