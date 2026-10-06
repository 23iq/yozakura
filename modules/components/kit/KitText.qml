import QtQuick
import qs.modules.components.kit

// Text in one of the kit's type roles (Type.roles): `KitText { role: "title" }`.
// Numbers are tabular in the display role (or with `tabular: true`).
Text {
    id: root

    property string role: "body"
    property bool tabular: role === "display"

    font.family: Type.family(root.role)
    font.pixelSize: Type.size(root.role)
    font.weight: Type.weight(root.role)
    font.letterSpacing: Type.letterSpacing(root.role)
    font.capitalization: Type.capitalization(root.role)
    font.features: root.tabular ? ({
            "tnum": 1
        }) : ({})
    color: Type.color(root.role)
    elide: Text.ElideRight
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
