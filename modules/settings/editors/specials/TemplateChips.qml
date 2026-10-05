pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import "../../../specials/Specials.js" as Specials

// Quick templates (Chat, Music, Dev, Notes, Custom): one button each,
// `chosen(templateId)` creates a special from it.
Flow {
    id: root

    signal chosen(string templateId)

    spacing: 8

    Repeater {
        model: Specials.TEMPLATES
        delegate: PillButton {
            required property var modelData
            objectName: "template:" + modelData.id
            kind: modelData.id === "custom" ? "filled" : "tonal"
            icon: modelData.id === "custom" ? "plus" : modelData.icon
            text: I18n.t(modelData.name || "specials.template.custom")
            onClicked: root.chosen(modelData.id)
        }
    }
}
