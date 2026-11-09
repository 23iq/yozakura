pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.components.kit

// Settings row: label over a kit Segmented selector. `options`: an array
// of {label, value, icon (optional)}; `valueSelected(value)` on a click.
ColumnLayout {
    id: root

    property string label: ""
    property var options: []
    property string value: ""
    // When false, a value matching no option selects nothing (used when
    // one setting is split across several rows).
    property bool fallbackToFirst: true

    signal valueSelected(string newValue)

    function getIndexFromValue(val: string): int {
        for (let i = 0; i < root.options.length; i++) {
            if (root.options[i].value === val)
                return i;
        }
        return root.fallbackToFirst ? 0 : -1;
    }

    Layout.fillWidth: true
    spacing: Space.xs
    opacity: root.enabled ? 1 : 0.45

    KitText {
        visible: root.label !== ""
        role: "secondary"
        text: root.label
    }

    Segmented {
        objectName: "rowSelector"
        enabled: root.enabled
        model: root.options.map(o => ({
                    "name": "option_" + o.value,
                    "icon": o.icon ?? "",
                    "text": o.label
                }))
        currentIndex: root.getIndexFromValue(root.value)
        onActivated: index => root.valueSelected(root.options[index].value)
    }
}
