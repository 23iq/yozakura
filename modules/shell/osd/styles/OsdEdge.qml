import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme
import qs.config
import qs.modules.shell.osd
import "../OsdStyles.js" as OsdStyles

// Slim bar hugging a screen edge. Vertical on left/right edges (level grows
// upwards, the device name runs sideways), horizontal on top/bottom.
StyledRect {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property bool vertical: false
    property bool shown: true
    readonly property bool dim: root.muted && root.kind !== "brightness"

    variant: "popup"
    implicitWidth: OsdStyles.sizeFor("edge", root.vertical, Metrics.osdW).w
    implicitHeight: OsdStyles.sizeFor("edge", root.vertical, Metrics.osdW).h
    radius: Math.min(width, height) / 2

    // Vertical: percent on top, track, icon at the bottom.
    ColumnLayout {
        visible: root.vertical
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 10
        spacing: 8

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: OsdStyles.percent(root.value)
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: root.dim ? Colors.error : Colors.overBackground
        }
        Item {
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 6

            OsdTrack {
                anchors.fill: parent
                vertical: true
                thickness: 6
                value: root.value
                muted: root.dim
                visible: root.device === ""
            }
            Text {
                anchors.centerIn: parent
                width: parent.height
                rotation: -90
                visible: root.device !== ""
                text: root.device
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
            }
        }
        OsdGlyph {
            Layout.alignment: Qt.AlignHCenter
            kind: root.kind
            value: root.value
            muted: root.muted
        }
    }

    // Horizontal: icon, track (or device name), percent.
    RowLayout {
        visible: !root.vertical
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        OsdGlyph {
            kind: root.kind
            value: root.value
            muted: root.muted
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            OsdTrack {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                thickness: 6
                value: root.value
                muted: root.dim
                visible: root.device === ""
            }
            Text {
                anchors.fill: parent
                visible: root.device !== ""
                text: root.device
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
            }
        }
        Text {
            text: OsdStyles.percent(root.value)
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: root.dim ? Colors.error : Colors.overBackground
        }
    }
}
