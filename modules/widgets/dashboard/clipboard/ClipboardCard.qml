import QtQuick
import qs.modules.components
import qs.modules.components.kit

// A clickable card of the clipboard preview (link embed, URL card, the
// loading state): the kit's control box with the language's padding
// (Look.boxPadding), the hover look while hovered. `clicked()`.
StyledRect {
    id: root

    property bool interactive: true
    readonly property bool hovered: root.interactive && mouse.containsMouse
    readonly property bool boxed: Look.boxedControls

    signal clicked

    variant: root.hovered ? "focus" : "common"
    backgroundOpacity: root.boxed ? 0 : -1
    enableBorder: !root.boxed
    radius: Look.radius("box")

    ControlBox {
        shown: root.boxed
        radius: root.radius
        hovered: root.hovered
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
