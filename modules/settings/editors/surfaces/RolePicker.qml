pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import "SurfaceRoles.js" as Roles
import qs.modules.components.kit

// Chips of every surface variant, in two groups (surfaces, accents); one
// is current across both. `picked(prop)` fires with the sr* name.
ColumnLayout {
    id: root

    property string current: "srBg"
    signal picked(string prop)

    spacing: Space.s

    Repeater {
        model: Roles.GROUPS

        delegate: ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth: true
            spacing: Space.xs

            KitText {
                role: "caption"
                text: I18n.t(group.modelData.label)
                color: Colors.overSurfaceVariant
            }
            SelectorControl {
                objectName: "surfaceRoles:" + group.modelData.id
                Layout.fillWidth: true
                options: Roles.options(group.modelData)
                value: root.current
                onSelected: v => root.picked(v)
            }
        }
    }
}
