pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.settings.controls
import "../Ui.js" as Ui
import "../../widgets/defaultview/activities/ActivityRegistry.js" as Registry

// notch.activities: the island's activities in display order. Drag a row
// by its handle to reorder, pick its side (leading / trailing) and switch
// it on or off. Media sits in the middle and only has the switch.
Item {
    id: root

    property var entry

    objectName: "islandActivitiesEditor"

    readonly property var list: Registry.resolve(Config.notch ? Config.notch.activities : [])
    readonly property int rowHeight: Metrics.rowHeight + Metrics.spacing
    // Motion tokens (var: their sub-objects are untyped for qmllint)
    readonly property var morph: Motion.morph

    implicitWidth: 480
    implicitHeight: root.list.length * root.rowHeight

    function write(next) {
        GlobalStates.markShellChanged();
        Config.notch.activities = Registry.toConfig(next);
    }

    Repeater {
        model: root.list.length

        delegate: Item {
            id: row
            required property int index
            readonly property var item: root.list[row.index]
            readonly property bool dragging: handle.drag.active

            width: root.width
            height: root.rowHeight
            // Dragging assigns y directly; releasing re-binds it to the slot
            y: row.index * root.rowHeight
            z: row.dragging ? 2 : 1

            Behavior on y {
                enabled: Config.animDuration > 0 && !row.dragging
                NumberAnimation {
                    duration: root.morph.duration
                    easing.type: root.morph.easing
                }
            }

            StyledRect {
                anchors.fill: parent
                anchors.bottomMargin: Metrics.spacing
                variant: row.dragging ? "focus" : "common"
                radius: Styling.radius(0)
                opacity: row.item && row.item.enabled ? 1 : 0.6
            }

            // Drag handle: the grip, moving the row freely along y
            Text {
                id: grip
                x: Metrics.spacing
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -Metrics.spacing / 2
                text: Icons.dotsNine
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(2)
                color: Ui.alpha(Colors.overBackground, 0.6)

                MouseArea {
                    id: handle
                    anchors.fill: parent
                    anchors.margins: -Metrics.spacing / 2
                    cursorShape: row.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: row
                    drag.axis: Drag.YAxis
                    drag.minimumY: 0
                    drag.maximumY: root.height - root.rowHeight
                    onReleased: {
                        const to = Math.round(row.y / root.rowHeight);
                        if (to !== row.index)
                            root.write(Registry.move(root.list, row.index, to));
                        row.y = Qt.binding(() => row.index * root.rowHeight);
                    }
                }
            }

            Text {
                anchors.left: grip.right
                anchors.leftMargin: Metrics.spacing
                anchors.right: controls.left
                anchors.verticalCenter: grip.verticalCenter
                text: row.item ? I18n.t("prefs.notch.activity." + row.item.id) : ""
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                color: Colors.overBackground
                elide: Text.ElideRight
            }

            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: Metrics.spacing
                anchors.verticalCenter: grip.verticalCenter
                spacing: Metrics.spacing

                SelectorControl {
                    visible: !!row.item && row.item.side !== "center"
                    anchors.verticalCenter: parent.verticalCenter
                    options: [
                        {
                            "value": "leading",
                            "label": "prefs.notch.activity.leading",
                            "icon": "alignLeft"
                        },
                        {
                            "value": "trailing",
                            "label": "prefs.notch.activity.trailing",
                            "icon": "alignRight"
                        }
                    ]
                    value: row.item ? row.item.side : "leading"
                    onSelected: v => root.write(Registry.setField(root.list, row.item.id, "side", v))
                }
                ToggleControl {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: !!row.item && row.item.enabled
                    onToggled: v => root.write(Registry.setField(root.list, row.item.id, "enabled", v))
                }
            }
        }
    }
}
