import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import "../Ui.js" as Ui

// Depth clock quick switch + a jump to its full settings (Desktop & Clock).
Item {
    id: root

    property var entry
    readonly property bool on: !!SettingsStore.get("desktop.depthClock")

    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(2), 18)
        color: Ui.alpha(Colors.overBackground, 0.06)
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.6)
    }

    Row {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        ToggleControl {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.on
            onToggled: v => SettingsStore.set("desktop.depthClock", v)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.on ? I18n.t("common.enabled") : I18n.t("common.disabled")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.overBackground
        }
    }

    PillButton {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        icon: "arrowSquareOut"
        text: I18n.t("prefs.wall.depth_clock.open")
        onClicked: SettingsStore.navigate("desktop", "clock", "")
    }
}
