pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components.kit

// A small menu of a destination's header (the history, the page's ⋯):
// rows on the popup surface under the button that opened it, right
// aligned with it. `items`: [{name, text, subtitle?, enabled?}] (a row is
// named "menu:" + name); `triggered(name)` on a click (the menu closes);
// `empty` is said when there is no row. Fades in and out (micro).
Popup {
    id: menu

    property var items: []
    property string empty: ""

    signal triggered(string name)

    // under the parent, its right edge on the parent's
    x: parent ? parent.width - width : 0
    y: parent ? parent.height + Space.xs : 0
    width: Space.px(300)
    padding: Space.xs
    margins: Space.s
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    background: Surface {
        padding: 0
        floating: true
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Motion.micro.duration
            easing.type: Motion.micro.easing
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: Motion.micro.duration
            easing.type: Motion.micro.easing
        }
    }

    contentItem: Column {
        KitText {
            visible: menu.items.length === 0 && menu.empty !== ""
            width: parent.width
            padding: Space.m
            role: "secondary"
            color: Type.muted
            text: menu.empty
        }
        Repeater {
            model: menu.items
            delegate: ListRow {
                required property var modelData
                objectName: "menu:" + modelData.name
                width: parent.width
                title: modelData.text
                subtitle: modelData.subtitle || ""
                enabled: modelData.enabled !== false
                opacity: enabled ? 1 : 0.45
                onClicked: {
                    menu.close();
                    menu.triggered(modelData.name);
                }
            }
        }
    }
}
