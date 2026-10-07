import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.shell.osd
import qs.modules.components.kit

// The OSD laid out along a side edge: the value on top, a vertical level line,
// the icon at the bottom (the "Muted" label or a new device runs sideways in
// place of the line). Shared by the pill and edge styles on left/right edges.
ColumnLayout {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property var readout: ({})

    spacing: Space.m

    KitText {
        Layout.alignment: Qt.AlignHCenter
        visible: root.readout.value !== ""
        role: "caption"
        tabular: true
        color: Type.secondary
        text: root.readout.value
    }
    Item {
        Layout.fillHeight: true
        Layout.fillWidth: true

        OsdTrack {
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            vertical: true
            value: root.value
            visible: root.readout.title === ""
        }
        KitText {
            anchors.centerIn: parent
            width: parent.height
            rotation: -90
            visible: root.readout.title !== ""
            role: "secondary"
            horizontalAlignment: Text.AlignHCenter
            text: root.readout.title
            color: root.readout.accent ? Type.accent : Type.text
            font.weight: root.readout.accent ? Font.DemiBold : Font.Normal
        }
    }
    OsdGlyph {
        Layout.alignment: Qt.AlignHCenter
        kind: root.kind
        value: root.value
        muted: root.muted
    }
}
