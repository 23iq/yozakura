import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.config
import qs.modules.components.kit

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

    KitText {
        role: "caption"
        Layout.preferredWidth: meta.labelWidth
        Layout.alignment: Qt.AlignTop
        text: meta.label
        color: Colors.overSurfaceVariant
        wrapMode: Text.Wrap
    }

    KitText {
        role: "caption"
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        visible: meta.value !== ""
        text: meta.value
        font.family: meta.mono ? Config.theme.monoFont : Config.theme.font
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
