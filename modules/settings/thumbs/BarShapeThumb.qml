pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "../../bar/panels/PanelStyles.js" as PanelStyles
import "BarShape.js" as BarShape

// Picture of a bar style (the Shape cards): a close crop of the bar's edge
// over your wallpaper, the bar across the whole picture and about a third
// of its height, with a few plain marks instead of module icons, so the
// styles differ by silhouette (BarShape.js). `edge` is the bar's edge; a
// style that cannot sit there is shown on its own first edge.
MiniScreen {
    id: root

    property string style: "classic"
    property string edge: "top"
    readonly property string shownEdge: PanelStyles.supportsEdge(root.style, root.edge) ? root.edge : PanelStyles.get(root.style).edges[0]
    readonly property bool vertical: root.shownEdge === "left" || root.shownEdge === "right"
    // the bar's thickness: a third of the picture's short side (a quarter
    // on a side edge, where the bar runs along that short side)
    readonly property real thick: Math.round(Math.min(root.width, root.height) / (root.vertical ? 4 : 3))
    readonly property var sketch: BarShape.shape(root.style, lane.width, root.thick)

    // The bar's frame, turned so its top lies on the edge.
    Item {
        id: lane
        width: root.vertical ? root.height : root.width
        height: root.vertical ? root.width : root.height
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        // the bar's start stays at the top / left of the screen
        rotation: root.shownEdge === "left" ? -90 : (root.shownEdge === "right" ? 90 : 0)
        // (after the turn: a flip across the screen's middle line)
        transform: Scale {
            origin.x: lane.width / 2
            origin.y: lane.height / 2
            yScale: root.shownEdge === "left" || root.shownEdge === "bottom" ? -1 : 1
        }

        Repeater {
            model: root.sketch.shapes
            delegate: Item {
                id: piece
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: modelData.h
                Mark {
                    anchors.fill: parent
                    visible: piece.modelData.kind !== "ghost"
                    radius: piece.modelData.r
                    // solid and edged: the outline is the subject
                    color: piece.modelData.kind === "dock" ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                    border.width: Space.hairline
                    border.color: Qt.alpha(Colors.overBackground, 0.28)
                }
                DashedFrame {
                    anchors.fill: parent
                    visible: piece.modelData.kind === "ghost"
                    radius: piece.modelData.r
                    color: Qt.alpha(Colors.overBackground, 0.55)
                }
            }
        }
        Repeater {
            model: root.sketch.marks
            delegate: Mark {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: modelData.h
                radius: modelData.r
                color: Qt.alpha(Colors.overBackground, modelData.kind === "seg" ? 0.9 : 0.72)
            }
        }
    }
}
