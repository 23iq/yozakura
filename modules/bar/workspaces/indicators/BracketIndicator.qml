import QtQuick
import qs.config
import qs.modules.theme

// "bracket": retro [1] brackets in the accent color around the label
// (opening downward/upward on vertical bars), in the mono font.
Item {
    id: root

    property var indicator: null
    width: indicator ? indicator.width : 0
    height: indicator ? indicator.height : 0
    readonly property bool vertical: indicator ? indicator.vertical : false
    readonly property real slot: indicator ? indicator.slotSize : 0
    readonly property real glyphSize: Math.max(8, Math.round(Math.min(Config.theme.fontSize, slot * 0.62)))

    component Bracket: Text {
        required property real size
        required property bool turned
        font.family: Config.theme.monoFont
        font.pixelSize: size
        font.weight: Font.Bold
        color: Colors.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        width: size
        height: size * 1.3
        rotation: turned ? 90 : 0
    }

    Bracket {
        size: root.glyphSize
        turned: root.vertical
        text: "["
        x: root.vertical ? (root.width - width) / 2 : Math.max(0, root.slot * 0.06 - width * 0.12)
        y: root.vertical ? Math.max(0, root.slot * 0.06 - height * 0.12) - (height - width) / 2 : (root.height - height) / 2
    }
    Bracket {
        size: root.glyphSize
        turned: root.vertical
        text: "]"
        x: root.vertical ? (root.width - width) / 2 : root.width - width - Math.max(0, root.slot * 0.06 - width * 0.12)
        y: root.vertical ? root.height - height + (height - width) / 2 - Math.max(0, root.slot * 0.06 - height * 0.12) : (root.height - height) / 2
    }
}
