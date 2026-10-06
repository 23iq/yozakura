pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import "SurfaceRoles.js" as Roles

// Chips of every surface variant, in two groups (surfaces, accents); one
// is current across both. `picked(prop)` fires with the sr* name.
ColumnLayout {
    id: root

    property string current: "srBg"
    signal picked(string prop)

    spacing: 8

    Repeater {
        model: Roles.GROUPS

        delegate: ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: I18n.t(group.modelData.label)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
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
