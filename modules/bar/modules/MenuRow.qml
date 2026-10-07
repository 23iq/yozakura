pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// One action row of a bar module popup: a kit ListRow with the action's
// glyph, its label and an optional shortcut hint. `danger` tints the glyph
// with the error color (destructive actions).
ListRow {
    id: row

    property string icon: ""
    property string label: ""
    property string hint: ""
    property bool danger: false
    signal triggered

    width: parent ? parent.width : implicitWidth
    implicitHeight: Space.controlM
    title: row.label
    onClicked: row.triggered()

    leading: Text {
        text: Icons[row.icon] ?? ""
        font.family: Icons.font
        font.pixelSize: Type.iconSize("body")
        color: row.danger ? Colors.error : Type.secondary
    }

    trailing: row.hint !== "" ? hintComponent : null

    Component {
        id: hintComponent
        KitText {
            role: "caption"
            text: row.hint
        }
    }
}
