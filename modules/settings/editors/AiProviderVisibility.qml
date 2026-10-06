pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.aicenter.providers
import "../../services/ai/ProviderPresets.js" as Presets

// ai.providers.hidden: one switch per provider ("show in the model
// picker"). A hidden provider is neither listed nor probed.
ColumnLayout {
    id: root

    property var entry

    readonly property var hidden: Config.ai.providers ? (Config.ai.providers.hidden || []) : []

    spacing: 6

    Repeater {
        model: Presets.sorted()
        delegate: RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: 10
            ProviderIcon {
                icon: row.modelData.icon || ""
                size: 18
            }
            AiToggleRow {
                objectName: "showProvider_" + row.modelData.id
                label: row.modelData.label
                checked: root.hidden.indexOf(row.modelData.id) < 0
                onToggled: v => Ai.providers.setHidden(row.modelData.id, !v)
            }
        }
    }
}
