pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The ⋯ menu of the active preset (settings sidebar footer): save, save as
// new, show changes, revert. Opens above its parent (the footer sits at the
// bottom of the window). Rows emit chosen(id).
Popup {
    id: root

    signal chosen(string id)

    readonly property var items: [
        {
            "id": "save",
            "icon": "check",
            "text": I18n.t("presets.status.save"),
            "enabled": PresetStatusService.owned && PresetStatusService.dirty
        },
        {
            "id": "saveAs",
            "icon": "plus",
            "text": I18n.t("presets.status.save_as"),
            "enabled": PresetStatusService.active !== "" && !PresetStatusService.inSession
        },
        {
            "id": "changes",
            "icon": "listChecks",
            "text": I18n.t("presets.status.show_changes"),
            "enabled": PresetStatusService.changed > 0
        },
        {
            "id": "revert",
            "icon": "arrowCounterClockwise",
            "text": I18n.t("presets.status.revert"),
            "enabled": PresetStatusService.dirty
        }
    ]

    objectName: "presetStatusMenu"
    y: -height - Space.xs
    width: Space.px(232)
    padding: Space.xs
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    background: Surface {
        padding: 0
        floating: true
    }
    contentItem: Column {
        spacing: 0
        Repeater {
            model: root.items
            delegate: ListRow {
                id: row
                required property var modelData
                objectName: "presetMenu:" + modelData.id
                width: root.availableWidth
                title: modelData.text
                visible: modelData.enabled
                onClicked: {
                    root.close();
                    root.chosen(row.modelData.id);
                }
                leading: Component {
                    Text {
                        text: Icons[row.modelData.icon] ?? ""
                        font.family: Icons.font
                        font.pixelSize: Type.iconSize("body")
                        color: Type.secondary
                    }
                }
            }
        }
    }
}
