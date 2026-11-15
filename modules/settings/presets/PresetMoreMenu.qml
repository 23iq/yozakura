pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components.kit

// The ⋯ menu of the preset studio's info panel: the rarer studio actions
// (Mixer, Browse, Import), under its button, right-aligned to it. `items`
// = [{ id, icon (an Icons name), text }]; a row emits chosen(id).
Popup {
    id: root

    property var items: []

    signal chosen(string id)

    objectName: "presetMoreMenu"
    y: parent ? parent.height + Space.xs : 0
    x: parent ? parent.width - width : 0
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
                objectName: "presetMore:" + modelData.id
                width: root.availableWidth
                title: modelData.text
                onClicked: {
                    root.close();
                    root.chosen(row.modelData.id);
                }
                leading: Component {
                    Icon {
                        icon: Icons[row.modelData.icon] ?? ""
                        color: Type.secondary
                    }
                }
            }
        }
    }
}
