import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.shell.osd
import "../OsdStyles.js" as OsdStyles

// Classic OSD: a floating pill with icon, label (or the device name right
// after an output switch), percentage and a level track.
StyledRect {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property bool vertical: false
    property bool shown: true

    variant: "popup"
    implicitWidth: OsdStyles.sizeFor("pill", false, Metrics.osdW).w
    implicitHeight: OsdStyles.sizeFor("pill", false, Metrics.osdW).h
    radius: Styling.radius(16)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 20
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 14

        OsdGlyph {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 28
            kind: root.kind
            value: root.value
            muted: root.muted
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: root.device !== "" ? root.device : I18n.t(OsdStyles.labelKey(root.kind))
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    color: Colors.overBackground
                }

                Text {
                    text: root.muted && root.kind !== "brightness" ? I18n.t("osd.muted") : OsdStyles.percent(root.value)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    color: root.muted ? Colors.error : Colors.overBackground
                }
            }

            OsdTrack {
                Layout.fillWidth: true
                value: root.value
                muted: root.muted && root.kind !== "brightness"
            }
        }
    }
}
