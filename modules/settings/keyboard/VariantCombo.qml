import QtQuick
import qs.modules.components.kit

// Compact dropdown over a layout's variants [{value, label}] (they can be
// dozens, too wide for segmented chips): the kit Dropdown, the first
// variant standing in for an unknown value.
Dropdown {
    id: root

    property var variants: []
    property string chosen: ""

    signal picked(string value)

    width: Math.min(Math.max(implicitWidth, Space.px(190)), Space.px(300))
    options: root.variants.map(o => ({
                "value": o.value,
                "text": o.label
            }))
    value: root.variants.some(o => o.value === root.chosen) ? root.chosen : (root.variants.length > 0 ? root.variants[0].value : "")
    onSelected: v => root.picked(String(v))
}
