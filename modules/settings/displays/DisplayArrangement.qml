pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../Ui.js" as Ui
import "DisplayFormat.js" as DisplayFormat

// The arrangement canvas: every enabled monitor as a scaled tile; drag one
// to move it (snaps to the others' edges on release). Disabled monitors sit
// in a strip underneath. `configs` is the draft layout, `outputs` the live
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
    radius: Styling.radius(4)
    enableShadow: false
    implicitHeight: 340 + (disabled.length > 0 ? strip.height + 14 : 0)

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
        anchors.fill: canvas
        opacity: 0.5
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: Colors
            function onOutlineChanged() {
                requestPaint();
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
        x: 16
        y: 16
        width: parent.width - 32
        height: 308
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

    Text {
        anchors.left: canvas.left
        anchors.bottom: canvas.bottom
        anchors.margins: 4
        text: I18n.t("prefs.displays.arrange_hint")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Ui.alpha(Colors.overSurfaceVariant, 0.8)
    }

    // Disabled monitors
    Flow {
        id: strip
        visible: root.disabled.length > 0
        x: 16
        y: canvas.y + canvas.height + 8
        width: parent.width - 32
        spacing: 8

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
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.xCircle ?? ""
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overSurfaceVariant
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: DisplayFormat.title(DisplayFormat.outputFor(root.outputs, off.modelData.name), off.modelData) + "  ·  " + I18n.t("prefs.displays.disabled")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
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
