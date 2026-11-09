import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Text button of the extras components: a kit Chip with keyboard focus.
// `kind`: "filled" is the one primary action of a surface (the accent
// fill); "tonal" / "ghost" / "solid" are the language's plain control box.
// `icon` is an Icons key ("downloadSimple").
Chip {
    id: root

    property string kind: "tonal"
    property string iconName: ""

    icon: root.iconName !== "" ? (Icons[root.iconName] ?? "") : ""
    primary: root.kind === "filled"
    activeFocusOnTab: true
    highlighted: root.activeFocus
    Accessible.role: Accessible.Button

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    FocusRing {
        shown: root.activeFocus
        radius: root.radius + Space.stroke
    }
}
