pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.config
import qs.modules.theme
import qs.modules.components.kit
import "BranchGeometry.js" as Geo

// The "branch" workspace indicator: a thin tapered branch through the slots
// with a node per workspace (BranchNode). Every colour is a palette role:
// the branch takes the muted ink, blossoms workspaces.branchColor, the
// active one the accent. `slots` comes from IndicatorStyles.stripSlots().
Item {
    id: root

    property bool vertical: false
    property real slot: 0
    property var slots: []
    property string shape: Config.workspaces.branchBlossom
    property string role: Config.workspaces.branchColor
    property bool petalFall: Config.workspaces.branchPetalFall

    readonly property color tint: Colors[Geo.role(root.role)]
    readonly property color stem: Qt.alpha(Type.muted, 0.9)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.WindingFill
            fillColor: root.stem
            PathSvg {
                path: Geo.branchPath(root.slots.length, root.slot, root.vertical)
            }
        }
    }

    Repeater {
        model: root.slots.length

        BranchNode {
            readonly property var centre: Geo.centre(index, root.slot, root.vertical)
            x: centre.x - root.slot / 2
            y: centre.y - root.slot / 2
            slotData: root.slots[index] || null
            slot: root.slot
            shape: Geo.shape(root.shape)
            tint: root.tint
            accent: Type.accent
            accentInk: Type.accentInk
            stem: root.stem
            alert: Colors.error
            petalFall: root.petalFall
        }
    }
}
