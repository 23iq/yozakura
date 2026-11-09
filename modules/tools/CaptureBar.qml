import QtQuick
import qs.modules.components
import qs.modules.components.kit

// The mode bar of the capture tools (screenshot, screen recording): a
// floating Surface holding the ActionGrid of modes and toggles. Takes the
// pointer over itself (no selection starts under it); focus goes to the
// grid (arrows move, Enter triggers).
FocusScope {
    id: root

    property alias actions: grid.actions
    property alias currentIndex: grid.currentIndex

    signal actionTriggered(var action)

    implicitWidth: surface.implicitWidth
    implicitHeight: surface.implicitHeight

    Surface {
        id: surface
        anchors.fill: parent
        floating: true

        ActionGrid {
            id: grid
            focus: true
            buttonSize: Space.controlM + Space.s
            iconSize: Type.iconSize("title")
            spacing: Space.s
            onActionTriggered: action => root.actionTriggered(action)
        }
    }

    // Under the grid: swallows hover and presses on the bar's padding.
    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        preventStealing: true
    }
}
