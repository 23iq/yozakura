import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

// A short explanation that appears next to a control while it is hovered
// or has keyboard focus (`shown`): secondary text, wrapped at a readable
// width, on the theme's popup surface. Declare it inside the item it
// explains; it opens below it after a short delay.
//
//   Tooltip { text: I18n.t(entry.description); shown: row.hovered }
ToolTip {
    id: root

    property bool shown: false

    delay: 550
    timeout: -1
    visible: root.shown && root.text.length > 0
    y: parent ? parent.height + Space.xs : 0
    padding: Space.m
    width: Math.min(root.contentItem.implicitWidth, Space.px(340)) + root.leftPadding + root.rightPadding
    margins: Space.s

    contentItem: KitText {
        role: "secondary"
        color: Type.text
        text: root.text
        wrapMode: Text.WordWrap
    }

    background: StyledRect {
        variant: "popup"
        radius: Look.radius("small", Space.controlS)
        enableShadow: true
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Motion.micro.duration
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: Motion.micro.duration
        }
    }
}
