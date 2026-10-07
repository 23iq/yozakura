import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.shell.osd
import qs.modules.components.kit
import "../OsdStyles.js" as OsdStyles

// A slim kit Surface hugging the free screen edge. Vertical on left/right
// edges (OsdVerticalBody). Horizontal on top/bottom: icon, line level and value, like the pill.
Surface {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property string currentDevice: ""
    property bool vertical: false
    property bool shown: true
    readonly property var readout: OsdStyles.readout(root.kind, root.value, root.muted, root.device, root.currentDevice, I18n.t("osd.muted"))

    padding: 0
    floating: true
    implicitWidth: OsdStyles.sizeFor("edge", root.vertical, Metrics.osdW).w
    implicitHeight: OsdStyles.sizeFor("edge", root.vertical, Metrics.osdW).h
    radius: Look.buttonRadius(Math.min(width, height))

    OsdVerticalBody {
        visible: root.vertical
        anchors.fill: parent
        anchors.topMargin: Space.l
        anchors.bottomMargin: Space.m
        kind: root.kind
        value: root.value
        muted: root.muted
        readout: root.readout
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
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            kind: root.kind
            value: root.value
            muted: root.muted
            device: root.device
            currentDevice: root.currentDevice
        }
        KitText {
            visible: root.readout.value !== ""
            role: "secondary"
            tabular: true
            text: root.readout.value
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: Type.size("secondary") * 2.6
        }
    }
}
