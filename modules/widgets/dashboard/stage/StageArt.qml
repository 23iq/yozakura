import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.config

// The hero's album art with a cross-fade on track change: two kit Arts,
// the new cover loads into the hidden one and fades in over the old.
Item {
    id: root

    property url source: ""
    property string icon: Icons.musicNotes
    property bool front: true

    function swap() {
        if (root.front) {
            back.source = root.source;
            root.front = false;
        } else {
            face.source = root.source;
            root.front = true;
        }
    }

    onSourceChanged: root.swap()
    Component.onCompleted: face.source = root.source

    component Layer: Art {
        anchors.fill: parent

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
    }

    Layer {
        id: face
        objectName: "art"
        icon: root.icon
        opacity: root.front ? 1 : 0
    }

    Layer {
        id: back
        icon: root.icon
        opacity: root.front ? 0 : 1
    }
}
