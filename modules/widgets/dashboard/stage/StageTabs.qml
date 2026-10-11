import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../DashboardTabs.js" as DashboardTabs

// The dashboard's tabs as one kit Segmented pill group (layout.dashboard.tabs
// order and visibility; the current tab on the sliding accent pill). Scroll
// over them to step through the tabs; `navigate(index)` with the stable tab
// index. Segments are named dashTab_<id>.
Segmented {
    id: root

    // Stable tab indices (DashboardTabs.tabs) in config order.
    property var order: [0, 1, 2]
    property int currentTab: 0

    signal navigate(int index)

    model: root.order.map(i => {
        const tab = DashboardTabs.tabs[i];
        return {
            "name": "dashTab_" + (tab ? tab.id : ""),
            "icon": tab ? (Icons[tab.icon] || "") : "",
            "text": tab ? I18n.t(tab.labelKey) : ""
        };
    })
    currentIndex: root.order.indexOf(root.currentTab)
    onActivated: index => root.navigate(root.order[index])

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const next = DashboardTabs.step(root.order, root.currentTab, event.angleDelta.y > 0 ? -1 : 1, false);
            if (next !== root.currentTab)
                root.navigate(next);
        }
    }
}
