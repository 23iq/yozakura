pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.store
import qs.modules.components.kit
import "OrderedList.js" as OrderedList

// An ordered pick list (an array of choice values): one row per choice
// with up / down arrows. `entry.choices`: [{value, label}] (i18n labels);
// `entry.subset: true` adds a switch per row (only the chosen ones are
// kept, in order), otherwise the list ranks every choice. Writes entry.key.
ColumnLayout {
    id: root

    property var entry

    readonly property var choices: root.entry && root.entry.choices ? root.entry.choices : []
    readonly property var values: root.choices.map(c => c.value)
    readonly property bool subset: !!(root.entry && root.entry.subset)
    readonly property var stored: root.entry ? SettingsStore.get(root.entry.key) : []
    readonly property var rows: OrderedList.rows(root.stored, root.values, root.subset)
    readonly property int onCount: root.rows.filter(r => r.on).length

    spacing: 0

    function labelOf(value) {
        const c = root.choices.find(x => x.value === value);
        return c ? I18n.t(c.label) : value;
    }

    function write(list) {
        SettingsStore.set(root.entry.key, list);
    }

    Repeater {
        model: root.rows

        delegate: ListRow {
            id: row

            required property var modelData
            required property int index
            readonly property bool on: modelData.on

            Layout.fillWidth: true
            objectName: "ordered:" + modelData.value
            title: root.labelOf(modelData.value)
            opacity: row.on ? 1 : 0.6

            trailing: Component {
                RowLayout {
                    spacing: Space.xs

                    IconButton {
                        size: "s"
                        icon: Icons.caretUp
                        enabled: row.on && row.index > 0
                        Accessible.name: I18n.t("prefs.bar.sentence.move_up")
                        onClicked: root.write(OrderedList.move(root.stored, root.values, root.subset, row.modelData.value, -1))
                    }
                    IconButton {
                        size: "s"
                        icon: Icons.caretDown
                        enabled: row.on && row.index < root.onCount - 1
                        Accessible.name: I18n.t("prefs.bar.sentence.move_down")
                        onClicked: root.write(OrderedList.move(root.stored, root.values, root.subset, row.modelData.value, 1))
                    }
                    Switch {
                        visible: root.subset
                        checked: row.on
                        Accessible.name: row.title
                        onToggled: v => root.write(OrderedList.toggle(root.stored, root.values, row.modelData.value, v))
                    }
                }
            }
        }
    }
}
