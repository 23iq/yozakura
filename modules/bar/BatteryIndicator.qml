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

    BarPopup {
        id: batteryPopup
        objectName: "batteryPopup"
        anchorItem: buttonBg
        bar: root.bar
        popupPadding: Look.surfacePadding

        contentWidth: Math.max(280, profiles.implicitWidth + Look.groupPadding * 2) + popupPadding * 2
        contentHeight: content.implicitHeight + popupPadding * 2

        Column {
            id: content
            width: parent.width
            spacing: Look.groupGap

            // Charge: percentage, status, a progress line and the time left
            Group {
                width: parent.width
                visible: Battery.available

                Item {
                    width: parent.width
                    height: percent.implicitHeight

                    KitText {
                        id: percent
                        role: "title"
                        tabular: true
                        text: Math.round(Battery.percentage) + "%"
                        color: root.low ? Colors.error : Type.text
                    }

                    KitText {
                        anchors.right: parent.right
                        anchors.left: percent.right
                        anchors.leftMargin: Space.m
                        anchors.verticalCenter: percent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        role: "secondary"
                        text: Battery.isPluggedIn ? (Battery.isCharging ? I18n.t("battery.charging") : I18n.t("battery.full")) : I18n.t("battery.on_battery")
                    }
                }

                ProgressLine {
                    width: parent.width
                    value: root.fraction
                }

                KitText {
                    width: parent.width
                    role: "caption"
                    visible: text !== ""
                    text: Battery.isPluggedIn ? (Battery.timeToFull !== "" ? I18n.t("battery.full_in", Battery.timeToFull) : I18n.t("battery.fully_charged")) : (Battery.timeToEmpty !== "" ? I18n.t("battery.remaining", Battery.timeToEmpty) : "")
                }
            }

            Group {
                width: parent.width
                label: I18n.t("battery.profile")
                divider: Battery.available

                Row {
                    id: profiles
                    spacing: Space.s

                    Repeater {
                        model: PowerProfileClient.availableProfiles

                        delegate: Chip {
                            required property string modelData
                            icon: PowerProfileClient.getProfileIcon(modelData)
                            text: PowerProfileClient.getProfileDisplayName(modelData)
                            active: PowerProfileClient.currentProfile === modelData
                            onClicked: PowerProfileClient.setProfile(modelData)
                        }
                    }
                }
            }
        }
    }
}
