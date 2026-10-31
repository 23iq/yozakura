import QtQuick
import qs.modules.components.kit
import "StripPhysics.js" as Physics

// Drag of a strip (Strip.qml), read along its hang axis: while held the
// strip tilts toward the pointer (`across`) and its thread stretches a
// little (`stretch`); on release StripPhysics.gesture says what it meant:
// "expand" (pulled away from the edge), "dismiss" (flicked back or swiped
// sideways) or "none".
DragHandler {
    id: root

    property string edge: "top"
    property real lastX: 0
    property real lastY: 0
    readonly property var along: Physics.project(root.edge, root.activeTranslation.x, root.activeTranslation.y)
    readonly property real across: root.active ? root.along.across : 0
    readonly property real stretch: root.active ? Math.max(-Space.xl, Math.min(Space.xxl, root.along.along)) * 0.5 : 0

    signal released(string action)

    target: null
    onActiveTranslationChanged: {
        if (root.active) {
            root.lastX = root.activeTranslation.x;
            root.lastY = root.activeTranslation.y;
        }
    }
    onActiveChanged: {
        if (root.active) {
            root.lastX = 0;
            root.lastY = 0;
        } else {
            root.released(Physics.gesture(root.edge, root.lastX, root.lastY, Space.xl));
        }
    }
}
