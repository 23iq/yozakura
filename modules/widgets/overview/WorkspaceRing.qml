import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The outline of a workspace thumbnail in the overview: the accent around
// the active / selected workspace, the outline ink around a drop target
// while a window is dragged over it, nothing otherwise. Same radius as the
// thumbnail (Look.radius "box").
Mark {
    property bool active: false
    property bool target: false

    radius: Look.radius("box")
    color: "transparent"
    border.width: active || target ? Space.hairline * 2 : 0
    border.color: active ? Type.accent : Colors.outline
}
