pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../widgets/dashboard/DashboardTabs.js" as DashboardTabs

// The dashboard's tabs (modules/widgets/dashboard/DashboardTabs.js), one
// line each in rail order (ReorderList: drag the grip, Up / Down on it, or
// its arrows), its icon and name, a switch to show or hide it (the last
// visible one stays). Writes layout.dashboard.tabs; the stage's rail follows.
ReorderList {
    id: root

    property var entry
    readonly property var tabs: DashboardTabs.resolve(SettingsStore.get("layout.dashboard.tabs"))
    readonly property int visibleCount: root.tabs.filter(t => t.visible).length

    function metaOf(id) {
        return DashboardTabs.tabs[DashboardTabs.indexOf(id)] || {};
    }

    name: "dashboardTab"
    keys: root.tabs.map(t => t.id)
    rowHeight: Space.controlM
    labelOf: id => I18n.t(root.metaOf(id).labelKey || "")
    onMoved: (id, from, to) => SettingsStore.set("layout.dashboard.tabs", DashboardTabs.move(root.tabs, id, to - from))

    row: Item {
        id: line
        property string rowKey: ""
        property int rowIndex: 0
        readonly property var tab: root.tabs.find(t => t.id === line.rowKey) || {}
        readonly property var meta: root.metaOf(line.rowKey)
        readonly property bool shown: line.tab.visible === true

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.s
            opacity: line.shown ? 1 : 0.45
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons[line.meta.icon] ?? ""
                role: "body"
                tone: line.shown ? "accent" : "muted"
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "body"
                text: I18n.t(line.meta.labelKey || "")
            }
        }

        Switch {
            objectName: "dashboardTabSwitch:" + line.rowKey
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: line.shown
            // the last visible tab cannot be hidden
            enabled: !line.shown || root.visibleCount > 1
            Accessible.name: I18n.t(line.meta.labelKey || "")
            onToggled: v => SettingsStore.set("layout.dashboard.tabs", DashboardTabs.setVisible(root.tabs, line.rowKey, v))
        }
    }
}
