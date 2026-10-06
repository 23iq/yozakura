import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.shell.osd
import "../OsdStyles.js" as OsdStyles

// Island capsule at the notch edge: a round dot that morphs open into icon,
// label and level. Standalone fallback for when the notch is not hosting the
// OSD itself (OsdService.toIsland).
StyledRect {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property bool vertical: false
    property bool shown: true

    readonly property size full: Qt.size(OsdStyles.sizeFor("island", false, Metrics.osdW).w, OsdStyles.sizeFor("island", false, Metrics.osdW).h)

    variant: "popup"
    implicitHeight: root.full.height
    implicitWidth: root.shown ? root.full.width : root.full.height
    radius: height / 2
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: OsdMotion.morphMs
            easing.type: OsdMotion.morphEasing
            easing.overshoot: OsdMotion.morphOvershoot
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 11
        anchors.rightMargin: 16
        spacing: 10

        OsdGlyph {
            Layout.preferredWidth: 22
            kind: root.kind
            value: root.value
            muted: root.muted
        }

        Text {
            Layout.fillWidth: true
            opacity: root.shown ? 1 : 0
            text: root.device !== "" ? root.device : I18n.t(OsdStyles.labelKey(root.kind))
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: OsdMotion.delayMs
                    }
                    NumberAnimation {
                        duration: OsdMotion.enterMs
                    }
                }
            }
        }

        Text {
            opacity: root.shown ? 1 : 0
            text: root.muted && root.kind !== "brightness" ? I18n.t("osd.muted") : OsdStyles.percent(root.value)
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: root.muted && root.kind !== "brightness" ? Colors.error : Styling.srItem("overprimary")
        }
    }

    // Thin level line along the bottom of the capsule.
    OsdTrack {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.height / 2
        anchors.rightMargin: root.height / 2
        anchors.bottomMargin: 4
        thickness: 2
        value: root.value
        muted: root.muted && root.kind !== "brightness"
        opacity: root.shown ? 1 : 0
    }
}
