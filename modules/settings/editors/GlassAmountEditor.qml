import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.store
import "../Ui.js" as Ui

// Master glass slider (theme.glass.amount). While the amount follows the
// preset (-1) the slider shows the preset's own amount; moving it pins a
// value, the chip goes back to the preset's look.
ColumnLayout {
    id: root

    property var entry
    readonly property real raw: Number(SettingsStore.get("theme.glass.amount") ?? -1)
    readonly property bool followsPreset: !(raw >= 0)
    readonly property real effective: followsPreset ? Glass.reference : raw

    spacing: 8

    SliderControl {
        objectName: "glassAmountSlider"
        Layout.fillWidth: true
        value: Math.round(root.effective * 100)
        from: 0
        to: 100
        stepSize: 1
        unit: "%"
        onMoved: v => SettingsStore.set("theme.glass.amount", Math.round(v) / 100)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: I18n.t("prefs.glass.level." + Glass.describe(root.effective))
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.DemiBold
            color: Colors.primary
        }

        Item {
            Layout.fillWidth: true
        }

        Rectangle {
            id: chip
            objectName: "glassFollowPreset"
            Layout.preferredHeight: 24
            Layout.preferredWidth: chipLabel.implicitWidth + 20
            radius: 12
            color: root.followsPreset ? Ui.alpha(Colors.primary, 0.16) : (chipArea.containsMouse ? Ui.alpha(Colors.overBackground, 0.12) : Ui.alpha(Colors.overBackground, 0.06))
            border.width: 1
            border.color: Ui.alpha(root.followsPreset ? Colors.primary : Colors.outlineVariant, 0.6)

            Text {
                id: chipLabel
                anchors.centerIn: parent
                text: I18n.t(root.followsPreset ? "prefs.glass.follows_preset" : "prefs.glass.use_preset").replace("%1", Math.round(Glass.reference * 100) + "%")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: root.followsPreset ? Colors.primary : Colors.overSurfaceVariant
            }

            MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.followsPreset
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.set("theme.glass.amount", -1)
            }
        }
    }
}
