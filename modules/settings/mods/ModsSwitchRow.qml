import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls

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
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: row.title
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.Medium
            color: Colors.overBackground
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            visible: row.description !== ""
            text: row.description
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
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
