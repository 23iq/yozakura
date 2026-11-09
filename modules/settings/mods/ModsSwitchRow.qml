import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.components.kit

// Label + description + switch. `toggled(value)` on user interaction.
RowLayout {
    id: row

    property string title: ""
    property string description: ""
    property bool checked: false
    signal toggled(bool value)

    width: parent ? parent.width : implicitWidth
    spacing: Metrics.spacing * 2

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Space.xs / 2

        KitText {
            Layout.fillWidth: true
            text: row.title
            font.weight: Font.Medium
            wrapMode: Text.Wrap
        }

        KitText {
            role: "caption"
            Layout.fillWidth: true
            visible: row.description !== ""
            text: row.description
            color: Colors.overSurfaceVariant
            wrapMode: Text.Wrap
        }
    }

    ToggleControl {
        Layout.alignment: Qt.AlignVCenter
        checked: row.checked
        enabled: row.enabled && !ModsService.busy
        Accessible.name: row.title
        onToggled: value => row.toggled(value)
    }
}
