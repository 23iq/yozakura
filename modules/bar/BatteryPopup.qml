pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.theme

// The battery popup: charge (percentage, status, a progress line, time
// left) and the power profile chips. Opened by the bar battery and the
// sentence bar's battery fragment.
BarPopup {
    id: popup

    readonly property real fraction: Battery.available ? Battery.percentage / 100 : 0
    readonly property bool low: Battery.available && Battery.percentage <= 15 && !Battery.isCharging

    objectName: "batteryPopup"
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
                    color: popup.low ? Colors.error : Type.text
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
                value: popup.fraction
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
