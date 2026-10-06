pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.config
import qs.modules.components.kit

// Middle of an upright island (notch on a side edge), top to bottom: the
// avatar, a hairline, the media disc (album art, or the play state; its
// hover/click open the media panel like the summary does), the muted mic
// and the notification bell. The horizontal header's parts re-laid along
// the edge, never rotated text.
Column {
    id: root

    property var player: null
    property int motionDuration: 0
    readonly property bool mediaHovered: mediaHover.hovered
    signal mediaClicked

    readonly property real discSize: Math.round(Styling.fontSize(10))
    spacing: Math.round(Styling.fontSize(-6))

    UserInfo {
        anchors.horizontalCenter: parent.horizontalCenter
    }
    Separator {
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: Math.round(root.discSize * 0.6)
    }

    Item {
        id: media
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.discSize
        height: root.player ? root.discSize : 0
        visible: height > 0
        clip: true
        Behavior on height {
            enabled: root.motionDuration > 0
            NumberAnimation {
                duration: root.motionDuration
                easing.type: Easing.OutCubic
            }
        }
        readonly property string art: root.player?.trackArtUrl ?? ""
        readonly property bool playing: root.player?.isPlaying ?? false

        // The artwork as an Avatar inside a Ring that is full while playing
        Ring {
            anchors.fill: parent
            value: media.playing ? 1 : 0
            Avatar {
                width: media.width - Space.stroke * 2 - 2
                height: width
                source: media.art
                icon: ""
            }
        }
        Text {
            anchors.centerIn: parent
            visible: media.art === "" || mediaHover.hovered
            text: media.playing ? Icons.pause : Icons.play
            font.family: Icons.font
            font.pixelSize: Type.iconSize("caption")
            color: media.art === "" ? Type.accent : Type.text
            style: Text.Outline
            styleColor: media.art === "" ? "transparent" : Colors.background
        }
        HoverHandler {
            id: mediaHover
        }
        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.mediaClicked()
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: MicrophoneStatus.available && MicrophoneStatus.muted
        text: Icons.micSlash
        font.family: Icons.font
        font.pixelSize: Styling.fontSize(4)
        color: Colors.criticalRed
    }
    NotificationIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
