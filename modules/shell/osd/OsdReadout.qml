import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.shell.osd
import qs.modules.components.kit
import "OsdStyles.js" as OsdStyles

// The middle of a horizontal OSD (pill, edge on top/bottom): the level line,
// titled by the new device after an output switch; while muted, the accent
// "Muted" label over the device as a caption instead (OsdStyles.readout).
ColumnLayout {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property string currentDevice: ""
    readonly property var readout: OsdStyles.readout(root.kind, root.value, root.muted, root.device, root.currentDevice, I18n.t("osd.muted"))

    spacing: Space.xs

    KitText {
        Layout.fillWidth: true
        visible: root.readout.title !== ""
        role: "body"
        text: root.readout.title
        color: root.readout.accent ? Type.accent : Type.text
        font.weight: root.readout.accent ? Font.DemiBold : Font.Normal
    }

    KitText {
        Layout.fillWidth: true
        visible: root.readout.caption !== ""
        role: "caption"
        text: root.readout.caption
    }

    OsdTrack {
        Layout.fillWidth: true
        Layout.topMargin: root.readout.title !== "" ? Space.xs : 0
        visible: root.readout.level
        value: root.value
    }
}
