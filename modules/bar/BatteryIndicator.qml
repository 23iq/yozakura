pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.bar.look
import qs.modules.theme

// Bar battery: a kit Ring (charge, accent; error when low) around the
// lightning / plug glyph, or the power profile glyph without a battery.
// Click: the battery popup (charge, time left, power profile chips).
Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius
    // Bar panels: module size, and "flat" (no group box of its own)
    property int moduleSize: BarMetrics.moduleSize
    property bool flat: false

    // Popup visibility state
    property bool popupOpen: batteryPopup.isOpen
    readonly property real fraction: Battery.available ? Battery.percentage / 100 : 0
    readonly property bool low: Battery.available && Battery.percentage <= 15 && !Battery.isCharging
    readonly property color levelColor: root.low ? Colors.error : Type.accent
    readonly property string glyph: Battery.available ? (Battery.isPluggedIn ? Icons.plug : Icons.lightning) : PowerProfileClient.getProfileIcon(PowerProfileClient.currentProfile)

    objectName: "batteryModule"
    Layout.preferredWidth: root.moduleSize
    Layout.preferredHeight: root.moduleSize
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    Item {
        id: buttonBg
        anchors.fill: parent

        ModuleBox {
            id: box
            vertical: root.vertical
            startRadius: root.startRadius
            endRadius: root.endRadius
            flat: root.flat
            shadow: root.layerEnabled
            active: root.popupOpen
            hovered: root.isHovered
        }

        Ring {
            anchors.centerIn: parent
            visible: Battery.available
            width: Math.round(root.moduleSize * 0.72)
            height: width
            value: root.fraction
            color: box.look === "primary" ? Type.accentInk : root.levelColor
        }

        Text {
            anchors.centerIn: parent
            text: root.glyph
            font.family: Icons.font
            font.pixelSize: Battery.available ? Math.round(BarLook.iconSize(root.moduleSize) * 0.72) : BarLook.iconSize(root.moduleSize)
            color: box.ink
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: batteryPopup.toggle()
        }

        StyledToolTip {
            visible: root.isHovered && !root.popupOpen
            tooltipText: Battery.available ? (Battery.isCharging ? I18n.t("battery.status_charging", Math.round(Battery.percentage), I18n.t("battery.charging")) : I18n.t("battery.status", Math.round(Battery.percentage))) : I18n.t("battery.power_profile", PowerProfileClient.getProfileDisplayName(PowerProfileClient.currentProfile))
        }
    }

    BatteryPopup {
        id: batteryPopup
        anchorItem: buttonBg
        bar: root.bar
    }
}
