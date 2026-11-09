pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.config
import qs.modules.aicenter.common

// One usage item of the composer strip (session cost or subscription
// limit): compact text, an optional mini bar, a tooltip and a click that
// opens the Usage screen.
StyledRect {
    id: root

    property string text: ""
    property string glyph: ""
    property real fraction: -1          // >= 0 draws a mini bar
    property string level: "ok"         // ok | warn | critical
    property string tooltip: ""
    property string detail: ""

    signal clicked

    readonly property color tone: level === "critical" ? Type.danger : (level === "warn" ? Colors.warning : Type.muted)

    implicitWidth: row.implicitWidth + 2 * Space.s
    implicitHeight: row.implicitHeight + 2 * Space.xs
    radius: Look.radius("control")
    variant: hover.hovered ? "common" : "transparent"
    enableBorder: false

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.clicked()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Space.xs
        Icon {
            role: "caption"
            visible: root.glyph.length > 0
            icon: root.glyph
            size: BarLook.size("caption")
            color: root.tone
        }
        LevelMeter {
            visible: root.fraction >= 0
            Layout.preferredWidth: Space.xxl - Space.xs
            Layout.preferredHeight: Space.xs
            Layout.alignment: Qt.AlignVCenter
            level: root.fraction
            tone: root.level === "ok" ? Type.progress : root.tone
        }
        AiText {
            objectName: "usageSlotText"
            role: "caption"
            text: root.text
            font.features: {
                "tnum": 1
            }
            color: root.tone
        }
    }

    StyledToolTip {
        tooltipText: root.tooltip
        desciription: root.detail
        show: hover.hovered && root.tooltip.length > 0
    }
}
