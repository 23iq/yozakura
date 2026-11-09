import QtQuick
import qs.modules.components.kit

// What a capture tool would take (the window under the pointer, the
// dragged region): an accent outline over a light accent wash, the
// selection of the frozen screen. Hidden (transparent) unless `lit`.
Mark {
    id: root

    property bool lit: true

    radius: 0
    color: "transparent"
    border.color: root.lit ? Type.accent : "transparent"
    border.width: Space.hairline * 2

    Mark {
        anchors.fill: parent
        radius: 0
        color: Type.accent
        opacity: root.lit ? 0.2 : 0
    }
}
