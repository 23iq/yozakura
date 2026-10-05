pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.store

// Per-surface glass overrides (theme.glass.surfaces.<surface>.amount).
// Off = the surface inherits the master amount (-1); on = its own amount.
ColumnLayout {
    id: root

    property var entry

    spacing: 4

    Repeater {
        model: Glass.surfaces

        delegate: RowLayout {
            id: surfaceRow
            required property string modelData
            readonly property string key: "theme.glass.surfaces." + modelData + ".amount"
            readonly property real raw: Number(SettingsStore.get(key) ?? -1)
            readonly property bool custom: raw >= 0

            objectName: "glassSurface:" + modelData
            Layout.fillWidth: true
            spacing: 12

            ToggleControl {
                checked: surfaceRow.custom
                onToggled: v => SettingsStore.set(surfaceRow.key, v ? Math.round(Glass.amount * 100) / 100 : -1)
            }

            Text {
                Layout.preferredWidth: 150
                text: I18n.t("prefs.glass.surface." + surfaceRow.modelData)
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }

            SliderControl {
                Layout.fillWidth: true
                enabled: surfaceRow.custom
                opacity: surfaceRow.custom ? 1 : 0.45
                value: Math.round((surfaceRow.custom ? surfaceRow.raw : Glass.amount) * 100)
                from: 0
                to: 100
                stepSize: 1
                unit: "%"
                onMoved: v => SettingsStore.set(surfaceRow.key, Math.round(v) / 100)
            }
        }
    }
}
