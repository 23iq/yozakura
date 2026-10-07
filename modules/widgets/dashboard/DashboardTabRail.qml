pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.globals
import qs.modules.services
import "DashboardTabs.js" as DashboardTabs

// Dashboard tab rail: one IconButton per visible tab (layout.dashboard.tabs
// order, the current one `active`); at the bottom the bento edit toggle (on
// the widgets tab in bento mode) and the settings button. Scroll to switch
// tabs.
Item {
    id: root

    // Stable tab indices (DashboardTabs.tabs) in rail order.
    property var order: [0, 1, 2]
    property int currentTab: 0
    property bool canEdit: false
    property bool editing: false
    property int tabSpacing: Space.s

    signal navigate(int index)
    signal editToggled

    implicitWidth: Space.controlM

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const next = DashboardTabs.step(root.order, root.currentTab, event.angleDelta.y > 0 ? -1 : 1, false);
            if (next !== root.currentTab)
                root.navigate(next);
        }
    }

    component RailButton: IconButton {
        id: btn

        property string tip: ""

        anchors.horizontalCenter: parent.horizontalCenter
        Accessible.name: btn.tip

        StyledToolTip {
            show: btn.hovered && btn.tip !== ""
            tooltipText: btn.tip
        }
    }

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: root.tabSpacing

        Repeater {
            model: root.order

            RailButton {
                required property int modelData
                readonly property var tab: DashboardTabs.tabs[modelData]

                objectName: "dashTab_" + (tab ? tab.id : "")
                icon: tab ? (Icons[tab.icon] || "") : ""
                tip: tab ? I18n.t(tab.labelKey) : ""
                active: root.currentTab === modelData
                onClicked: root.navigate(modelData)
            }
        }
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: root.tabSpacing

        RailButton {
            objectName: "bentoEditToggle"
            visible: root.canEdit
            icon: root.editing ? Icons.check : Icons.pencil
            active: root.editing
            tip: I18n.t(root.editing ? "bento.done" : "bento.edit")
            onClicked: root.editToggled()
        }

        RailButton {
            objectName: "settingsButton"
            icon: Icons.gear
            active: GlobalStates.settingsWindowVisible
            onClicked: GlobalShortcuts.toggleSettings()
        }
    }
}
