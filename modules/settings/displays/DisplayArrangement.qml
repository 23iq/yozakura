pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../Ui.js" as Ui
import "DisplayFormat.js" as DisplayFormat
import qs.modules.components.kit

// The arrangement canvas (the Displays page's hero): every enabled monitor
// as a scaled tile; drag one to move it (snaps to the others' edges on
// release), click one to pick it. Disabled monitors sit in a strip
// underneath. `configs` is the draft layout, `outputs` the live
// outputs (model names, wallpaper aspect).
StyledRect {
    id: root

    property var configs: []
    property var outputs: []
    property string selectedName: ""

    signal picked(string name)
    // The dragged monitor's drop position, logical px
    signal moved(string name, real x, real y)

    readonly property var numbers: DisplayFormat.numbering(configs)
    readonly property var layout: DisplayFormat.fitLayout(configs, canvas.width, canvas.height)
    readonly property var disabled: configs.filter(c => c.enabled === false)

    variant: "pane"
    radius: Look.radius("box")
    enableShadow: false
    readonly property int margin: Space.l
    // the canvas takes the height the page gives, less the strip of
    // monitors that are off
    readonly property real canvasHeight: Math.max(Space.controlXL, root.height - margin * 2 - (disabled.length > 0 ? strip.height + Space.m : 0))
    implicitHeight: Space.px(340)

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.55)
        z: 10
    }

    // Dotted grid backdrop
    Canvas {
        id: grid
        anchors.fill: canvas
        opacity: 0.5
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: Colors
            function onOutlineChanged() {
                grid.requestPaint();
            }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Qt.alpha(Colors.outline, 0.35);
            const step = 22;
            for (let gx = step / 2; gx < width; gx += step)
                for (let gy = step / 2; gy < height; gy += step)
                    ctx.fillRect(gx, gy, 1.5, 1.5);
        }
    }

    Item {
        id: canvas
        objectName: "arrangementCanvas"
        x: root.margin
        y: root.margin
        width: parent.width - root.margin * 2
        height: root.canvasHeight
        clip: true

        Repeater {
            id: tiles
            objectName: "tiles"
            model: root.configs.length

            delegate: DisplayTile {
                id: t
                required property int index
                readonly property var cfg: root.configs[t.index]
                objectName: "tile:" + (cfg ? cfg.name : "")
                visible: !!cfg && cfg.enabled !== false
                config: cfg ?? ({
                        "name": "",
                        "x": 0,
                        "y": 0,
                        "width": 0,
                        "height": 0,
                        "scale": 1,
                        "transform": 0
                    })
                output: cfg ? DisplayFormat.outputFor(root.outputs, cfg.name) : null
                number: cfg ? (root.numbers[cfg.name] ?? 0) : 0
                selected: !!cfg && cfg.name === root.selectedName
                pxScale: root.layout.scale
                originX: root.layout.ox
                originY: root.layout.oy
                onPicked: root.picked(t.config.name)
                onDropped: (lx, ly) => root.moved(t.config.name, lx, ly)
            }
        }
    }

    // Disabled monitors
    Flow {
        id: strip
        visible: root.disabled.length > 0
        x: root.margin
        y: canvas.y + canvas.height + Space.m
        width: parent.width - root.margin * 2
        spacing: Space.s

        Repeater {
            model: root.disabled

            delegate: Item {
                id: off
                required property var modelData
                readonly property bool on: off.modelData.name === root.selectedName
                width: offRow.implicitWidth + 26
                height: 32

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: off.on ? Ui.alpha(Colors.primary, 0.2) : Ui.alpha(Colors.overBackground, 0.05)
                    border.width: off.on ? 2 : 1
                    border.color: off.on ? Colors.primary : Ui.alpha(Colors.outline, 0.35)
                }
                Row {
                    id: offRow
                    anchors.centerIn: parent
                    spacing: Space.s
                    Icon {
                        tone: "secondary"
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.xCircle ?? ""
                    }
                    KitText {
                        role: "secondary"
                        anchors.verticalCenter: parent.verticalCenter
                        text: DisplayFormat.title(DisplayFormat.outputFor(root.outputs, off.modelData.name), off.modelData) + "  ·  " + I18n.t("prefs.displays.disabled")
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(off.modelData.name)
                }
            }
        }
    }
}
