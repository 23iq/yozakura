import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// "Launch ⏎": what a key does, then the key as a small keycap.
//   cap: {kind, text, icon} as in modules/keybinds/KeyNames.js
RowLayout {
    id: hint

    property string text: ""
    property var cap: ({
            "kind": "icon",
            "icon": "arrowElbowDownLeft",
            "text": ""
        })
    property color color: Colors.overBackground

    spacing: 6
    visible: text !== ""

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutCubic
        }
    }

    Text {
        text: hint.text
        color: hint.color
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-3)
        font.weight: Font.Medium
    }

    Keycap {
        cap: hint.cap
        sizeOffset: -4
    }
}
