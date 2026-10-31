pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.settings.previews
import "../Ui.js" as Ui
import "../../theme/VisualLanguage.js" as VisualLanguage

// Card picture of a visual language (theme.language): a mini window drawn
// from that language's kit spec (VisualLanguage.KIT): its groups (fill,
// outline, radius, dividers) and its controls (fill, round or square; the
// device language turns a knob).
ScreenBackdrop {
    id: root

    property var entry
    property var value: "ink"
    readonly property var spec: VisualLanguage.KIT[VisualLanguage.normalize(String(value))] || {}
    readonly property var group: spec.group || {}
    readonly property var control: spec.control || null
    readonly property bool knobs: !!(spec.instrument && spec.instrument.levelControl === "knob")
    readonly property real unit: Math.min(width, height) / 10

    function role(name, alpha) {
        const c = Colors[name] ?? Colors.surfaceContainer;
        return Ui.alpha(c, alpha);
    }

    function radiusOf(kind) {
        return ({
                "none": 0,
                "small": root.unit * 0.4,
                "card": root.unit * 0.9
            })[kind] ?? root.unit * 0.6;
    }

    // the window: frosted where the language has a see-through window
    Rectangle {
        id: win
        anchors.fill: parent
        anchors.margins: root.unit * 0.8
        radius: root.unit * 0.8
        color: root.spec.window ? root.role(root.spec.window.fill, root.spec.window.fillOpacity) : Colors.surface
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.4)

        Column {
            anchors.fill: parent
            anchors.margins: root.unit * 0.7
            spacing: root.unit * 0.6

            Repeater {
                model: 2
                delegate: Item {
                    id: groupItem
                    required property int index
                    width: parent.width
                    height: (win.height - root.unit * 2) / 2

                    Rectangle {
                        anchors.fill: parent
                        radius: root.radiusOf(root.group.radius)
                        color: root.group.fill ? root.role(root.group.fill, root.group.fillOpacity) : "transparent"
                        border.width: root.group.outline > 0 ? 1 : 0
                        border.color: Ui.alpha(Colors.overBackground, root.group.outline || 0)
                    }

                    // the hairline of the dividing languages
                    Rectangle {
                        visible: root.group.divider === true && groupItem.index === 0
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -root.unit * 0.3
                        width: parent.width
                        height: 1
                        color: Ui.alpha(Colors.overBackground, 0.18)
                    }

                    Rectangle {
                        x: root.unit * 0.6
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.38
                        height: Math.max(2, root.unit * 0.45)
                        radius: height / 2
                        color: Ui.alpha(Colors.overSurface, 0.6)
                    }

                    // the control: a pill or square chip, or a knob
                    Rectangle {
                        readonly property bool knob: root.knobs && groupItem.index === 1
                        anchors.right: parent.right
                        anchors.rightMargin: root.unit * 0.6
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.round(parent.height * 0.6)
                        width: knob ? height : height * 2
                        radius: knob ? height / 2 : (root.control && root.control.shape === "square" ? root.unit * 0.3 : height / 2)
                        color: groupItem.index === 0 ? Colors.primary : (root.control ? root.role(root.control.fill, Math.max(root.control.rest, 0.12)) : Colors.primaryContainer)
                        border.width: root.control && root.control.edge > 0 ? 1 : 0
                        border.color: Ui.alpha(Colors.overBackground, root.control ? root.control.edge : 0)

                        Rectangle {
                            visible: parent.knob
                            x: parent.width / 2 - width / 2
                            y: parent.height * 0.14
                            width: 2
                            height: parent.height * 0.3
                            color: Colors.primary
                        }
                    }
                }
            }
        }
    }
}
