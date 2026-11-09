import QtQuick
import QtQuick.Layouts
import qs.modules.components.kit

// Settings row: label + kit Switch. `toggled(value)` fires on user changes
// only; `checked` follows the bound value.
RowLayout {
    id: root

    property string label: ""
    property bool checked: false

    signal toggled(bool value)

    Layout.fillWidth: true
    spacing: Space.s

    // The Switch dims itself while disabled; only the label dims here.
    KitText {
        Layout.fillWidth: true
        opacity: root.enabled ? 1 : 0.45
        role: "body"
        text: root.label
    }

    Switch {
        objectName: "rowSwitch"
        enabled: root.enabled
        checked: root.checked
        onToggled: value => root.toggled(value)
    }
}
