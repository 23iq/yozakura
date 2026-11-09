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
    opacity: root.enabled ? 1 : 0.45

    KitText {
        Layout.fillWidth: true
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
