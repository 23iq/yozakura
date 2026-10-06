pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config
import qs.modules.components.signatures
import "DashboardTabs.js" as DashboardTabs

// Dashboard tab rail: the visible tabs (layout.dashboard.tabs order), the
// bento edit toggle (on the widgets tab) and the settings button.
Item {
    id: root

    // Stable tab indices (DashboardTabs.tabs) in rail order.
    property var order: [0, 1, 2]
    property int currentTab: 0
    property bool canEdit: false
    property bool editing: false
    property int tabSpacing: Metrics.spacing

    signal navigate(int index)
    signal editToggled

    readonly property int railPos: order.indexOf(currentTab)

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const next = DashboardTabs.step(root.order, root.currentTab, event.angleDelta.y > 0 ? -1 : 1, false);
            if (next !== root.currentTab)
                root.navigate(next);
        }
    }

    // Elastic highlight behind the current tab
    StyledRect {
        id: tabHighlight
        variant: "primary"
        width: parent.width
        radius: Styling.radius(4)
        visible: root.railPos >= 0
        z: 0

        BrushHighlight {}

        property real targetY: Math.max(0, root.railPos) * (width + root.tabSpacing)
        property real animatedY1: targetY
        property real animatedY2: targetY

        x: 0
        y: Math.min(animatedY1, animatedY2)
        height: Math.abs(animatedY2 - animatedY1) + width

        Behavior on animatedY1 {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration / 3
                easing.type: Easing.OutSine
            }
        }
        Behavior on animatedY2 {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Easing.OutSine
            }
        }

        onTargetYChanged: {
            animatedY1 = targetY;
            animatedY2 = targetY;
        }
    }

    component RailButton: Button {
        id: btn

        property string glyph: ""
        property bool active: false
        property string tip: ""

        flat: true
        hoverEnabled: true
        width: root.width
        height: width
        Accessible.name: tip

        background: Item {}

        contentItem: Text {
            text: btn.glyph
            textFormat: Text.RichText
            color: btn.active ? Styling.srItem("primary") : Colors.overBackground
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(6)
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on color {
                enabled: Motion.enter.duration > 0
                ColorAnimation {
                    duration: Motion.enter.duration
                    easing.type: Motion.enter.easing
                }
            }
        }

        StyledToolTip {
            show: btn.hovered
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
                glyph: tab ? (Icons[tab.icon] || "") : ""
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

        // Bento edit toggle (✎)
        Item {
            width: parent.width
            height: root.canEdit ? width : 0
            visible: height > 0
            clip: true

            Behavior on height {
                enabled: Motion.morph.duration > 0
                NumberAnimation {
                    duration: Motion.morph.duration
                    easing.type: Motion.morph.easing
                }
            }

            StyledRect {
                anchors.fill: parent
                radius: Styling.radius(4)
                variant: root.editing ? "primary" : (editButton.hovered ? "focus" : "common")
            }

            RailButton {
                id: editButton
                objectName: "bentoEditToggle"
                glyph: root.editing ? Icons.check : Icons.pencil
                active: root.editing
                tip: I18n.t(root.editing ? "bento.done" : "bento.edit")
                onClicked: root.editToggled()
            }
        }

        // Settings
        Item {
            width: parent.width
            height: width

            StyledRect {
                anchors.fill: parent
                radius: Styling.radius(4)
                variant: controlsButton.hovered ? "focus" : "common"
                opacity: GlobalStates.settingsWindowVisible ? 0 : 1

                Behavior on opacity {
                    enabled: Motion.enter.duration > 0
                    NumberAnimation {
                        duration: Motion.enter.duration
                        easing.type: Motion.enter.easing
                    }
                }
            }

            RailButton {
                id: controlsButton
                glyph: Icons.gear
                active: GlobalStates.settingsWindowVisible
                onClicked: GlobalShortcuts.toggleSettings()
            }
        }
    }
}
