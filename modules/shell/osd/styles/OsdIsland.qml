import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.shell.osd
import qs.modules.components.kit
import "../OsdStyles.js" as OsdStyles

// Island capsule at the notch edge: a round kit Surface that morphs open
// into icon, label (or the new device) and value, with a line level along
// its bottom. Standalone fallback for when the notch is not hosting the OSD
// itself (OsdService.toIsland).
Surface {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property string currentDevice: ""
    property bool vertical: false
    property bool shown: true

    readonly property size full: Qt.size(OsdStyles.sizeFor("island", false, Metrics.osdW).w, OsdStyles.sizeFor("island", false, Metrics.osdW).h)
    readonly property var readout: OsdStyles.readout(root.kind, root.value, root.muted, root.device, root.currentDevice, I18n.t("osd.muted"))

    padding: 0
    implicitHeight: root.full.height
    implicitWidth: root.shown ? root.full.width : root.full.height
    radius: Look.buttonRadius(height)
    clip: true

    Behavior on implicitWidth {
        enabled: OsdMotion.morphMs > 0
        NumberAnimation {
            duration: OsdMotion.morphMs
            easing.type: OsdMotion.morphEasing
            easing.overshoot: OsdMotion.morphOvershoot
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Space.m
        anchors.rightMargin: Space.l
        spacing: Space.s

        OsdGlyph {
            Layout.preferredWidth: Type.iconSize("body")
            kind: root.kind
            value: root.value
            muted: root.muted
        }

        KitText {
            id: label
            Layout.fillWidth: true
            opacity: root.shown ? 1 : 0
            role: "body"
            text: root.readout.title !== "" && !root.readout.accent ? root.readout.title : I18n.t(OsdStyles.labelKey(root.kind))

            Behavior on opacity {
                enabled: OsdMotion.enterMs > 0
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

        KitText {
            opacity: label.opacity
            role: "secondary"
            tabular: true
            text: root.readout.accent ? root.readout.title : root.readout.value
            color: root.readout.accent ? Type.accent : Type.secondary
            font.weight: root.readout.accent ? Font.DemiBold : Font.Normal
        }
    }

    // The level line along the bottom of the capsule.
    OsdTrack {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.height / 2
        anchors.rightMargin: root.height / 2
        anchors.bottomMargin: Space.xs
        value: root.value
        visible: root.readout.level
        opacity: label.opacity
    }
}
