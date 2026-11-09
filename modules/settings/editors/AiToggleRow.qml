import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config
import "../controls"
import qs.modules.components.kit

// Label + switch for the AI editors (settings v2 controls).
RowLayout {
    id: root

    property string label: ""
    property bool checked: false
    signal toggled(bool value)

    Layout.fillWidth: true
    spacing: Space.s

    KitText {
        role: "secondary"
        visible: root.label.length > 0
        Layout.fillWidth: true
        text: root.label
        wrapMode: Text.Wrap
        color: Colors.overBackground
    }
    ToggleControl {
        checked: root.checked
        onToggled: value => root.toggled(value)
    }
}
