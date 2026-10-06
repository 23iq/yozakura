pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui

// The settings a mod declares (ModsService.settingsFields, loaded for the
// selected mod), one ModsSettingField each, separated by hairlines.
ColumnLayout {
    id: form

    required property string modId

    width: parent ? parent.width : implicitWidth
    spacing: Metrics.spacing

    Text {
        text: I18n.t("mods.settings")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.DemiBold
        color: Colors.overBackground
    }

    Text {
        visible: ModsService.settingsBusy
        text: I18n.t("mods.loading_settings")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
    }

    Repeater {
        model: ModsService.settingsFields

        delegate: ColumnLayout {
            id: slot
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: Metrics.spacing

            Rectangle {
                visible: slot.index > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Ui.alpha(Colors.outlineVariant, 0.45)
            }

            ModsSettingField {
                Layout.fillWidth: true
                spec: slot.modelData
                modId: form.modId
            }
        }
    }
}
