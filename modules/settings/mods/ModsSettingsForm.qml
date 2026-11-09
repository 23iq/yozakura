pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui
import qs.modules.components.kit

// The settings a mod declares (ModsService.settingsFields, loaded for the
// selected mod), one ModsSettingField each, separated by hairlines.
ColumnLayout {
    id: form

    required property string modId

    width: parent ? parent.width : implicitWidth
    spacing: Metrics.spacing

    KitText {
        role: "secondary"
        text: I18n.t("mods.settings")
        font.weight: Font.DemiBold
        color: Colors.overBackground
    }

    KitText {
        role: "caption"
        visible: ModsService.settingsBusy
        text: I18n.t("mods.loading_settings")
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

            Divider {
                visible: Look.dividers && (slot.index > 0)
                Layout.fillWidth: true
            }

            ModsSettingField {
                Layout.fillWidth: true
                spec: slot.modelData
                modId: form.modId
            }
        }
    }
}
