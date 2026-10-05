pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.config
import "../keybinds/KeyNames.js" as KeyNames

// A key combo ({modifiers, key} as in binds.json) as a row of keycaps:
// modifiers in canonical order, the Super key as the app glyph. An empty
// key shows `placeholder` (e.g. "Not set") instead.
Row {
    id: root

    property var modifiers: []
    property string key: ""
    property int sizeOffset: -2
    property string tone: "normal"
    property string placeholder: ""

    readonly property var caps: KeyNames.caps(modifiers, key)

    spacing: Math.round(Styling.fontSize(sizeOffset) * 0.3)

    Accessible.role: Accessible.StaticText
    Accessible.name: KeyNames.comboText(modifiers, key)

    Repeater {
        model: root.caps
        delegate: Keycap {
            required property var modelData
            cap: modelData
            sizeOffset: root.sizeOffset
            tone: root.tone
        }
    }

    Text {
        visible: root.key === "" && root.placeholder !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: root.placeholder
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(root.sizeOffset)
        font.italic: true
        color: Colors.outline
    }
}
