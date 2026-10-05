pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import "../PanelSketch.js" as PanelSketch
import "../Ui.js" as Ui

// Whole-screen schematic of a panel set: wallpaper backdrop, frame, the
// notch, every panel drawn by its style (PanelSketch.js) with its module
// icons, and two windows in the space the panels leave. Clicking a panel
// picks it; the selected one is outlined.
Item {
    id: root

    property var panels: []
    property int selected: -1
    property string notchEdge: Config.notchPosition !== undefined ? Config.notchPosition : "top"
    property bool showNotch: true
    property bool showWindows: true
    // Module size in mockup pixels
    property real unit: Math.max(9, Math.round(width * 0.03))
    readonly property real frame: Config.bar && Config.bar.frameEnabled ? Math.max(2, Math.round(unit * 0.3)) : 0
    signal picked(int index)

    readonly property var sketches: panels.map(p => PanelSketch.sketch(p, width - 2 * frame, height - 2 * frame, unit))
    readonly property var depths: {
        const d = {
            "top": 0,
            "bottom": 0,
            "left": 0,
            "right": 0
        };
        for (let i = 0; i < panels.length; i++)
            d[panels[i].edge] = Math.max(d[panels[i].edge], sketches[i].depth);
        return d;
    }

    implicitHeight: Math.round(width * 9 / 16)

    ScreenBackdrop {
        anchors.fill: parent
    }

    // Frame
    Rectangle {
        visible: root.frame > 0
        anchors.fill: parent
        color: "transparent"
        radius: Math.min(Styling.radius(0), 14)
        border.width: root.frame
        border.color: Colors.background
    }

    // Windows in the free area
    Repeater {
        model: root.showWindows ? [[0, 0, 0.6, 1], [0.6, 0, 0.4, 1]] : []
        delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property real ax: root.frame + root.depths.left + root.unit * 0.4
            readonly property real ay: root.frame + root.depths.top + root.unit * 0.4
            readonly property real aw: root.width - ax - root.frame - root.depths.right - root.unit * 0.4
            readonly property real ah: root.height - ay - root.frame - root.depths.bottom - root.unit * 0.4
            x: ax + modelData[0] * aw + (index > 0 ? root.unit * 0.2 : 0)
            y: ay
            width: modelData[2] * aw - (index > 0 ? root.unit * 0.2 : 0)
            height: ah
            radius: Math.min(Styling.radius(-4), 8)
            color: Ui.alpha(Colors.surfaceContainer, 0.82)
            border.width: 1
            border.color: Ui.alpha(index === 0 ? Colors.primary : Colors.outlineVariant, 0.8)
        }
    }

    // Panels
    Repeater {
        model: root.panels.length
        delegate: Item {
            id: panel
            required property int index
            readonly property var sk: root.sketches[index]
            readonly property bool isSelected: index === root.selected
            readonly property bool hidden: root.panels[index].autohide === "always"
            x: root.frame
            y: root.frame
            width: root.width - 2 * root.frame
            height: root.height - 2 * root.frame
            opacity: hidden && !isSelected ? 0.45 : 1

            Repeater {
                model: panel.sk.shapes
                delegate: Rectangle {
                    required property var modelData
                    x: modelData.x
                    y: modelData.y
                    width: modelData.w
                    height: modelData.h
                    radius: Math.min(modelData.r, Styling.radius(0))
                    color: modelData.kind === "dock" ? Ui.alpha(Colors.surfaceContainerHigh, 0.95) : Colors.background
                    border.width: panel.isSelected ? 2 : (modelData.kind === "dock" ? 1 : 0)
                    border.color: panel.isSelected ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.8)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(panel.index)
                    }
                }
            }

            Repeater {
                model: panel.sk.icons
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
                    font.pixelSize: Math.round(modelData.size * 0.82)
                    color: panel.isSelected ? Colors.primary : Colors.overBackground
                }
            }
        }
    }

    // Notch
    Rectangle {
        visible: root.showNotch
        width: Math.round(root.width * 0.15)
        height: Math.round(root.unit * 1.25)
        x: (root.width - width) / 2
        y: root.notchEdge === "bottom" ? root.height - root.frame - height : root.frame
        radius: height / 2
        color: Colors.surfaceContainerLowest
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.7)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.36
            height: 3
            radius: 1.5
            color: Ui.alpha(Colors.overBackground, 0.35)
        }
    }
}
