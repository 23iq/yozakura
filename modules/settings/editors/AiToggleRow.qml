import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config
import "../controls"

// Label + switch for the AI editors (settings v2 controls).
RowLayout {
    id: root

    property string label: ""
    property bool checked: false
    signal toggled(bool value)

    Layout.fillWidth: true
    spacing: 8

    Text {
        visible: root.label.length > 0
        Layout.fillWidth: true
        text: root.label
        wrapMode: Text.Wrap
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overBackground
    }
    ToggleControl {
        checked: root.checked
        onToggled: value => root.toggled(value)
    }
}
