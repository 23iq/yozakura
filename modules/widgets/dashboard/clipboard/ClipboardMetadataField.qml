import QtQuick
import qs.modules.theme
import qs.config

// Label + value pair of the metadata strip.
Column {
    id: field

    property string label: ""
    property string value: ""
    // Clip the value to the column width (with `valueElide`).
    property bool elideValue: false
    property int valueElide: Text.ElideRight

    spacing: 2

    Text {
        text: field.label
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.weight: Font.Medium
        color: Colors.outline
    }

    Text {
        text: field.value
        font.family: Config.theme.font
        font.pixelSize: Config.theme.fontSize
        font.weight: Font.Normal
        color: Colors.overBackground
        elide: field.elideValue ? field.valueElide : Text.ElideNone
        width: field.elideValue ? field.width : implicitWidth
    }
}
