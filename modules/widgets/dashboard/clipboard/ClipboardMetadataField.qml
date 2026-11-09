import QtQuick
import qs.modules.components.kit

// Label + value pair of the metadata strip.
Column {
    id: field

    property string label: ""
    property string value: ""
    // Clip the value to the column width (with `valueElide`).
    property bool elideValue: false
    property int valueElide: Text.ElideRight

    spacing: Space.xs / 2

    KitText {
        role: "caption"
        text: field.label
    }

    KitText {
        width: field.elideValue ? field.width : implicitWidth
        role: "body"
        text: field.value
        elide: field.elideValue ? field.valueElide : Text.ElideNone
    }
}
