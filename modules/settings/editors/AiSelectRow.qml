import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config
import "../controls"
import qs.modules.components.kit

// Label + segmented choice (options: [{value, label: i18n key}]).
ColumnLayout {
    id: root

    property string label: ""
    property var options: []
    property var value
    signal selected(var value)

    Layout.fillWidth: true
    spacing: Space.xs

    KitText {
        role: "secondary"
        visible: root.label.length > 0
        text: root.label
        font.weight: Font.Medium
    }
    SelectorControl {
        Layout.fillWidth: true
        options: root.options
        value: root.value
        onSelected: v => root.selected(v)
    }
}
