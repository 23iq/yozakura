pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import "../PanelSketch.js" as PanelSketch

// The bar.panels of a preset inside its miniature (PresetMiniShell): every
// panel drawn by its style (PanelSketch.js: bands, tabs, a floating dock)
// with its module icons, in the preset's palette. Panels that auto-hide
// always are left out, like on a resting desktop.
Item {
    id: root

    // [{edge, style, groups, ...}] as in bar.json
    property var panels: []
    // Module size in miniature pixels
    property real unit: 12
    property color chrome: "black"
    property color ink: "white"
    property color line: "gray"

    readonly property var shown: panels.filter(p => p && p.autohide !== "always")
    readonly property var sketches: shown.map(p => PanelSketch.sketch(p, width, height, unit))
    // Space the panels take from each edge (windows start after it)
    readonly property var depths: {
        const d = {
            "top": 0,
            "bottom": 0,
            "left": 0,
            "right": 0
        };
        for (let i = 0; i < shown.length; i++)
            d[shown[i].edge] = Math.max(d[shown[i].edge], sketches[i].depth);
        return d;
    }

    Repeater {
        model: root.sketches
        delegate: Item {
            id: panel
            required property var modelData
            anchors.fill: parent

            Repeater {
                model: panel.modelData.shapes
                delegate: Rectangle {
                    required property var modelData
                    x: modelData.x
                    y: modelData.y
                    width: modelData.w
                    height: modelData.h
                    radius: modelData.r
                    color: root.chrome
                    border.width: modelData.kind === "dock" ? 1 : 0
                    border.color: root.line
                }
            }
            Repeater {
                model: panel.modelData.icons
                delegate: Text {
                    required property var modelData
                    x: modelData.x
                    y: modelData.y
                    width: modelData.size
                    height: modelData.size
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Icons[modelData.icon] ?? ""
                    font.family: Icons.font
                    font.pixelSize: Math.max(4, Math.round(modelData.size * 0.8))
                    color: root.ink
                }
            }
        }
    }
}
