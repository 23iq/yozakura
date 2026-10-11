pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../DashboardTabs.js" as DashboardTabs

// The dashboard's tabs as labelled kit Chips (layout.dashboard.tabs order
// and visibility, the current one active). Scroll over them to step
// through the tabs; `navigate(index)` with the stable tab index.
Row {
    id: root

    // Stable tab indices (DashboardTabs.tabs) in config order.
    property var order: [0, 1, 2]
    property int currentTab: 0

    signal navigate(int index)

    spacing: Space.xs

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const next = DashboardTabs.step(root.order, root.currentTab, event.angleDelta.y > 0 ? -1 : 1, false);
            if (next !== root.currentTab)
                root.navigate(next);
        }
    }

    Repeater {
        model: root.order

        Chip {
            required property int modelData
            readonly property var tab: DashboardTabs.tabs[modelData]

            objectName: "dashTab_" + (tab ? tab.id : "")
            icon: tab ? (Icons[tab.icon] || "") : ""
            text: tab ? I18n.t(tab.labelKey) : ""
            active: root.currentTab === modelData
            Accessible.name: text
            onClicked: root.navigate(modelData)
        }
    }
}
