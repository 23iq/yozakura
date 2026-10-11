import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The stage home's empty state, one grammar for every block (nothing next,
// no notifications): a quiet icon tile and one secondary line, fading in
// (no flicker when data arrives right after open).
Row {
    id: root

    property string icon: ""
    property string text: ""

    spacing: Space.m
    opacity: root.visible ? 1 : 0

    Behavior on opacity {
        enabled: Motion.micro.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration
        }
    }

    Art {
        anchors.verticalCenter: parent.verticalCenter
        width: Space.controlS
        height: width
        icon: root.icon
    }

    KitText {
        anchors.verticalCenter: parent.verticalCenter
        role: "secondary"
        text: root.text
    }
}
