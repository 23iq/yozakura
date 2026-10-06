import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config

// One label/value line of the package details. The label column has a
// fixed width so a stack of these reads as a table; children (link
// buttons, state text) go to the trailing slot.
RowLayout {
    id: meta

    property string label: ""
    property string value: ""
    property bool mono: false
    default property alias trailing: trailingSlot.data

    readonly property int labelWidth: Metrics.menuW - 40

    // Fills a plain Column as well as a ColumnLayout.
    width: parent ? parent.width : implicitWidth
    Layout.fillWidth: true
    spacing: Metrics.spacing + 2

    Text {
        Layout.preferredWidth: meta.labelWidth
        Layout.alignment: Qt.AlignTop
        text: meta.label
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
        wrapMode: Text.Wrap
    }

    Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        visible: meta.value !== ""
        text: meta.value
        font.family: meta.mono ? Config.theme.monoFont : Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overBackground
        wrapMode: Text.WrapAnywhere
    }

    Item {
        Layout.fillWidth: true
        visible: meta.value === ""
    }

    RowLayout {
        id: trailingSlot
        Layout.alignment: Qt.AlignVCenter
        spacing: Metrics.spacing - 2
    }
}
