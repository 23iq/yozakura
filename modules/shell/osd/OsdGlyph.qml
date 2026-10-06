import QtQuick
import qs.modules.theme
import qs.modules.shell.osd
import qs.modules.services
import "OsdStyles.js" as OsdStyles

// The OSD icon for a kind and level. Muted is a distinct state: a crossed
// icon in the error color. Brightness turns and swells with the level.
Text {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    readonly property string levelState: OsdStyles.stateOf(root.kind, root.value, root.muted)

    text: {
        if (root.kind === "mic")
            return root.levelState === "muted" ? Icons.micSlash : Icons.mic;
        if (root.kind === "brightness")
            return root.value < 0.34 ? Icons.sunDim : Icons.sun;
        return root.levelState === "muted" ? Icons.speakerSlash : Audio.volumeIcon(root.value, false);
    }
    font.family: Icons.font
    font.pixelSize: 22
    color: root.levelState === "muted" ? Colors.error : Colors.overBackground
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    rotation: root.kind === "brightness" ? root.value * 180 : 0
    scale: root.kind === "brightness" ? 0.8 + root.value * 0.2 : 1

    Behavior on rotation {
        NumberAnimation {
            duration: OsdMotion.enterMs
            easing.type: OsdMotion.enterEasing
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: OsdMotion.enterMs
            easing.type: OsdMotion.enterEasing
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: OsdMotion.enterMs
        }
    }
}
