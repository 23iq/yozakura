pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../widgets/dashboard/DashboardTabs.js" as DashboardTabs

// The dashboard's tabs (modules/widgets/dashboard/DashboardTabs.js), one
// line each in rail order: its icon and name, arrows on hover to move it
// up or down, a switch to show or hide it (the last visible one stays).
// Writes layout.dashboard.tabs; the stage's rail follows.
Column {
    id: root

    property var entry
    readonly property var tabs: DashboardTabs.resolve(SettingsStore.get("layout.dashboard.tabs"))
    readonly property int visibleCount: root.tabs.filter(t => t.visible).length

    spacing: 0

    Repeater {
        model: root.tabs
        delegate: Item {
            id: line
            required property var modelData
            required property int index
            readonly property var meta: DashboardTabs.tabs[DashboardTabs.indexOf(modelData.id)] || {}
            objectName: "dashboardTabRow:" + modelData.id
            width: root.width
            height: Space.controlM

            HoverHandler {
                id: hover
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.s
                opacity: line.modelData.visible ? 1 : 0.45
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons[line.meta.icon] ?? ""
                    role: "body"
                    tone: line.modelData.visible ? "accent" : "muted"
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "body"
                    text: I18n.t(line.meta.labelKey || "")
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs
                Repeater {
                    model: [-1, 1]
                    delegate: IconButton {
                        id: arrow
                        required property int modelData
                        objectName: "dashboardTabMove:" + line.modelData.id + (modelData < 0 ? ":up" : ":down")
                        size: "xs"
                        opacity: hover.hovered ? 1 : 0
                        enabled: modelData < 0 ? line.index > 0 : line.index < root.tabs.length - 1
                        icon: modelData < 0 ? Icons.caretUp : Icons.caretDown
                        tooltip: I18n.t(modelData < 0 ? "prefs.dashboard.move_up" : "prefs.dashboard.move_down")
                        onClicked: SettingsStore.set("layout.dashboard.tabs", DashboardTabs.move(root.tabs, line.modelData.id, arrow.modelData))
                    }
                }
                Switch {
                    objectName: "dashboardTabSwitch:" + line.modelData.id
                    anchors.verticalCenter: parent.verticalCenter
                    checked: line.modelData.visible
                    // the last visible tab cannot be hidden
                    enabled: !line.modelData.visible || root.visibleCount > 1
                    Accessible.name: I18n.t(line.meta.labelKey || "")
                    onToggled: v => SettingsStore.set("layout.dashboard.tabs", DashboardTabs.setVisible(root.tabs, line.modelData.id, v))
                }
            }
        }
    }
}
