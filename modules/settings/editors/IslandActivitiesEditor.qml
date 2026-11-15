pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.store
import qs.config
import qs.modules.settings.controls
import "../../widgets/defaultview/activities/ActivityRegistry.js" as Registry
import qs.modules.components.kit

// notch.activities: the island's activities in display order (ReorderList:
// drag a row by its grip, Up / Down on it, or its arrows), the side it
// shows on (leading / trailing) and a switch. Media sits in the middle and
// only has the switch. In a card of the page row (`fillHeight`): whole rows,
// the rest scrolls with a fade at the foot.
ReorderList {
    id: root

    property var entry
    readonly property var list: Registry.resolve(Config.notch ? Config.notch.activities : [])

    function write(next) {
        SettingsStore.set("notch.activities", Registry.toConfig(next));
    }
    function itemOf(id) {
        return root.list.find(e => e.id === id) || null;
    }

    objectName: "islandActivitiesEditor"
    name: "activity"
    keys: root.list.map(e => e.id)
    rowHeight: Space.controlM + Space.xs
    labelOf: id => I18n.t("prefs.notch.activity." + id)
    onMoved: (id, from, to) => root.write(Registry.move(root.list, from, to))

    row: Item {
        id: line
        property string rowKey: ""
        property int rowIndex: 0
        readonly property var item: root.itemOf(line.rowKey)

        KitText {
            anchors.left: parent.left
            anchors.right: controls.left
            anchors.rightMargin: Space.s
            anchors.verticalCenter: parent.verticalCenter
            role: "body"
            opacity: line.item && line.item.enabled ? 1 : 0.45
            text: I18n.t("prefs.notch.activity." + line.rowKey)
            elide: Text.ElideRight
        }

        Row {
            id: controls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.m

            SelectorControl {
                visible: !!line.item && line.item.side !== "center"
                // a narrow card: the side as two icons
                iconOnly: root.width < Space.px(440)
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
                value: line.item ? line.item.side : "leading"
                onSelected: v => root.write(Registry.setField(root.list, line.rowKey, "side", v))
            }
            ToggleControl {
                objectName: "activitySwitch:" + line.rowKey
                anchors.verticalCenter: parent.verticalCenter
                checked: !!line.item && line.item.enabled
                Accessible.name: I18n.t("prefs.notch.activity." + line.rowKey)
                onToggled: v => root.write(Registry.setField(root.list, line.rowKey, "enabled", v))
            }
        }
    }
}
