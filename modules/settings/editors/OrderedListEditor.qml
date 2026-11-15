pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.store
import qs.modules.components.kit
import "OrderedList.js" as OrderedList

// An ordered pick list (an array of choice values) as a ReorderList: one
// row per choice. `entry.choices`: [{value, label}] (i18n labels);
// `entry.subset: true` adds a switch per row (only the chosen ones are
// kept, in order, and only they move), otherwise the list ranks every
// choice. Writes entry.key.
ReorderList {
    id: root

    property var entry

    readonly property var choices: root.entry && root.entry.choices ? root.entry.choices : []
    readonly property var values: root.choices.map(c => c.value)
    readonly property bool subset: !!(root.entry && root.entry.subset)
    readonly property var stored: root.entry ? SettingsStore.get(root.entry.key) : []
    readonly property var rows: OrderedList.rows(root.stored, root.values, root.subset)

    function nameOf(value) {
        const c = root.choices.find(x => x.value === value);
        return c ? I18n.t(c.label) : value;
    }

    function write(list) {
        SettingsStore.set(root.entry.key, list);
    }

    name: "ordered"
    keys: root.rows.map(r => r.value)
    movable: root.rows.filter(r => r.on).length
    rowHeight: Space.controlM
    labelOf: value => root.nameOf(value)
    onMoved: (value, from, to) => root.write(OrderedList.move(root.stored, root.values, root.subset, value, to - from))

    row: Item {
        id: line
        property string rowKey: ""
        property int rowIndex: 0
        readonly property bool on: line.rowIndex < root.movable
        objectName: "ordered:" + line.rowKey

        KitText {
            anchors.left: parent.left
            anchors.right: toggle.visible ? toggle.left : parent.right
            anchors.rightMargin: Space.s
            anchors.verticalCenter: parent.verticalCenter
            role: "body"
            opacity: line.on ? 1 : 0.45
            text: root.nameOf(line.rowKey)
            elide: Text.ElideRight
        }
        Switch {
            id: toggle
            visible: root.subset
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: line.on
            Accessible.name: root.nameOf(line.rowKey)
            onToggled: v => root.write(OrderedList.toggle(root.stored, root.values, line.rowKey, v))
        }
    }
}
