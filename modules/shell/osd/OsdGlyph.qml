import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.shell.osd
import qs.modules.components.kit
import "OsdStyles.js" as OsdStyles

// The OSD icon for a kind and level, at the kit's icon size. Muted is a
// distinct state: the crossed icon, quieted to the muted ink (the "Muted"
// label next to it carries the accent).
Text {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string role: "body"
    readonly property string levelState: OsdStyles.stateOf(root.kind, root.value, root.muted)

    text: {
        if (root.kind === "mic")
            return root.levelState === "muted" ? Icons.micSlash : Icons.mic;
        if (root.kind === "brightness")
            return root.value < 0.34 ? Icons.sunDim : Icons.sun;
        return root.levelState === "muted" ? Icons.speakerSlash : Audio.volumeIcon(root.value, false);
    }
    font.family: Icons.font
    font.pixelSize: Type.iconSize(root.role)
    color: root.levelState === "muted" ? Type.muted : Type.secondary
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        enabled: OsdMotion.enterMs > 0
        ColorAnimation {
            duration: OsdMotion.enterMs
        }
    }
}
