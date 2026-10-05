import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config
import "../controls"

// Label + segmented choice (options: [{value, label: i18n key}]).
ColumnLayout {
    id: root

    property string label: ""
    property var options: []
    property var value
    signal selected(var value)

    Layout.fillWidth: true
    spacing: 4

    Text {
        visible: root.label.length > 0
        text: root.label
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.Medium
        color: Colors.overSurfaceVariant
    }
    SelectorControl {
        Layout.fillWidth: true
        options: root.options
        value: root.value
        onSelected: v => root.selected(v)
    }
}
