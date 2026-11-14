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
//
// `bounds` (an ancestor, e.g. the row or card it explains): the tooltip
// stays inside its width (never over a neighbouring column). It hides
// while the view it is in scrolls, and stays hidden until it is pointed
// at again.
ToolTip {
    id: root

    property bool shown: false
    property Item bounds: null
    // the scrolling view around it (found when it is pointed at)
    property Item view: null
    property bool scrolled: false
    onShownChanged: {
        if (!root.shown) {
            root.scrolled = false;
            return;
        }
        let p = root.parent;
        while (p && !("flicking" in p && "contentY" in p))
            p = p.parent;
        root.view = p;
    }
    Connections {
        target: root.shown ? root.view : null
        function onContentYChanged() {
            root.scrolled = true;
        }
        function onContentXChanged() {
            root.scrolled = true;
        }
    }
    // room from the parent's left edge to the end of `bounds`
    readonly property real room: root.bounds && root.parent ? root.bounds.width - root.parent.mapToItem(root.bounds, 0, 0).x - root.leftPadding - root.rightPadding : Space.px(340)

    delay: 550
    timeout: -1
    visible: root.shown && !root.scrolled && root.text.length > 0
    y: parent ? parent.height + Space.xs : 0
    padding: Space.m
    width: Math.max(Space.px(120), Math.min(root.contentItem.implicitWidth, Space.px(340), root.room)) + root.leftPadding + root.rightPadding
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
