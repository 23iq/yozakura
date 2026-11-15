pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// One choice of options [{value, label (i18n key), icon (Icons name)}]:
// the kit Segmented for up to `segmentLimit` options (Tab focus, Left /
// Right step), a kit Dropdown past it. Visual choices are picture cards
// instead (schema `display: "cards"`, CardSelector).
Item {
    id: root

    property var options: []
    property var value
    // false: labels are already display text (e.g. language names)
    property bool translate: true
    property int segmentLimit: 4
    // segments show their icons only (a narrow place; the name is the
    // accessible name)
    property bool iconOnly: false
    // fill the width given (a settings card's control column): equal
    // segments edge to edge, the dropdown as wide
    property bool stretch: false
    readonly property bool dropdown: root.options.length > root.segmentLimit
    signal selected(var value)

    readonly property int currentIndex: root.options.findIndex(o => o.value === root.value)

    // The segmented's own width (each segment as wide as its content),
    // whatever `stretch`: a host lines several selectors up on the widest.
    readonly property real naturalWidth: root.dropdown ? menu.implicitWidth : segments.naturalWidth

    function labelOf(o: var): string {
        return root.translate ? I18n.t(o.label) : String(o.label);
    }

    implicitWidth: root.dropdown ? menu.implicitWidth : segments.implicitWidth
    implicitHeight: root.dropdown ? menu.height : segments.implicitHeight

    Segmented {
        id: segments
        objectName: "selectorSegments"
        visible: !root.dropdown
        focus: !root.dropdown
        focusable: true
        width: root.stretch ? root.width : implicitWidth
        // the room past its own width shared by the segments
        segmentExtra: root.stretch && root.options.length > 0 ? Math.max(0, (root.width - root.naturalWidth) / root.options.length) : 0
        model: root.dropdown ? [] : root.options.map(o => ({
                    "name": "option:" + o.value,
                    "icon": o.icon ? (Icons[o.icon] ?? "") : "",
                    "text": root.iconOnly && o.icon ? "" : root.labelOf(o)
                }))
        currentIndex: root.currentIndex
        onActivated: i => root.selected(root.options[i].value)
    }

    Dropdown {
        id: menu
        visible: root.dropdown
        focus: root.dropdown
        width: root.stretch ? root.width : (root.width > 0 ? Math.min(root.width, Math.max(implicitWidth, Space.px(240))) : implicitWidth)
        // as tall as a segmented: the two read as one family
        height: Space.controlM
        options: root.dropdown ? root.options.map(o => ({
                    "value": o.value,
                    "text": root.labelOf(o),
                    "icon": o.icon ? (Icons[o.icon] ?? "") : ""
                })) : []
        value: root.value
        onSelected: v => root.selected(v)
    }
}
