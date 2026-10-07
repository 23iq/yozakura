import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.shell.osd
import qs.modules.components.kit
import "../OsdStyles.js" as OsdStyles

// Classic OSD: a floating kit Surface pill with the level icon, a line level
// and the value. Muted: the crossed icon, the accent "Muted" label and the
// device as a caption. An output switch titles the level with the device.
// On a left/right edge the pill stands upright (OsdVerticalBody).
Surface {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property string currentDevice: ""
    property bool vertical: false
    property bool shown: true
    readonly property var size: OsdStyles.sizeFor("pill", root.vertical, Metrics.osdW)

    padding: 0
    floating: true
    implicitWidth: root.size.w
    implicitHeight: root.size.h
    radius: Look.buttonRadius(Math.min(width, height))

    OsdVerticalBody {
        visible: root.vertical
        anchors.fill: parent
        anchors.topMargin: Space.l
        anchors.bottomMargin: Space.l
        kind: root.kind
        value: root.value
        muted: root.muted
        readout: OsdStyles.readout(root.kind, root.value, root.muted, root.device, root.currentDevice, I18n.t("osd.muted"))
    }

    RowLayout {
        visible: !root.vertical
        anchors.fill: parent
        anchors.leftMargin: Space.l
        anchors.rightMargin: Space.l
        spacing: Space.m

        OsdGlyph {
            Layout.preferredWidth: Type.iconSize("body")
            kind: root.kind
            value: root.value
            muted: root.muted
        }

        OsdReadout {
            id: readout
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            kind: root.kind
            value: root.value
            muted: root.muted
            device: root.device
            currentDevice: root.currentDevice
        }

        KitText {
            visible: readout.readout.value !== ""
            role: "secondary"
            tabular: true
            text: readout.readout.value
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: Type.size("secondary") * 2.6
        }
    }
}
