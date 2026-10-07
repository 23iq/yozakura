pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// One choice of options [{value, label (i18n key), icon (Icons name)}]:
// segmented kit Chips (the current one active) for short sets, wrapping onto
// several lines when they do not fit; a kit Dropdown for long sets
// (`dropdown`, more than `chipLimit` options).
Item {
    id: root

    property var options: []
    property var value
    // false: labels are already display text (e.g. language names)
    property bool translate: true
    property int chipLimit: 5
    readonly property bool dropdown: root.options.length > root.chipLimit
    signal selected(var value)

    readonly property int currentIndex: root.options.findIndex(o => o.value === root.value)

    function labelOf(o: var): string {
        return root.translate ? I18n.t(o.label) : String(o.label);
    }

    // Width of all chips on one line. Inline rows give the control its
    // implicit width, so the Flow must not derive its width from ours.
    readonly property real rowWidth: {
        let w = 0;
        const n = chips.count;
        for (let i = 0; i < n; i++) {
            const it = chips.itemAt(i);
            if (it)
                w += it.implicitWidth;
        }
        return Math.ceil(w + Math.max(0, n - 1) * flow.spacing) + 1;
    }

    implicitWidth: root.dropdown ? menu.implicitWidth : root.rowWidth
    implicitHeight: root.dropdown ? menu.implicitHeight : flow.implicitHeight
    activeFocusOnTab: !root.dropdown

    Keys.onLeftPressed: if (root.currentIndex > 0)
        root.selected(root.options[root.currentIndex - 1].value)
    Keys.onRightPressed: if (root.currentIndex < root.options.length - 1)
        root.selected(root.options[root.currentIndex + 1].value)

    Flow {
        id: flow
        visible: !root.dropdown
        width: Math.max(root.width, 0) || root.rowWidth
        spacing: Space.xs

        Repeater {
            id: chips
            model: root.dropdown ? [] : root.options

            delegate: Chip {
                required property var modelData
                required property int index
                icon: modelData.icon ? (Icons[modelData.icon] ?? "") : ""
                text: root.labelOf(modelData)
                active: index === root.currentIndex
                highlighted: root.activeFocus && active
                onClicked: {
                    root.forceActiveFocus();
                    root.selected(modelData.value);
                }
            }
        }
    }

    Dropdown {
        id: menu
        visible: root.dropdown
        width: root.width > 0 ? Math.min(root.width, Math.max(implicitWidth, Space.px(280))) : implicitWidth
        options: root.dropdown ? root.options.map(o => ({
                    "value": o.value,
                    "text": root.labelOf(o),
                    "icon": o.icon ? (Icons[o.icon] ?? "") : ""
                })) : []
        value: root.value
        onSelected: v => root.selected(v)
    }
}
