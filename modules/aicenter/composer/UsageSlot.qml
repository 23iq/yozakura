pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
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

    readonly property color tone: level === "critical" ? Colors.error : (level === "warn" ? Colors.warning : Colors.outline)

    implicitWidth: row.implicitWidth + 12
    implicitHeight: row.implicitHeight + 6
    radius: Styling.radius(-4)
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
        spacing: 5
        Text {
            visible: root.glyph.length > 0
            text: root.glyph
            font.family: Icons.font
            font.pixelSize: BarLook.font(-5)
            color: root.tone
        }
        StyledRect {
            visible: root.fraction >= 0
            Layout.preferredWidth: 28
            Layout.preferredHeight: 4
            Layout.alignment: Qt.AlignVCenter
            variant: "internalbg"
            radius: 2
            enableBorder: false
            // Fill of the bar.
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.fraction))
                height: parent.height
                radius: parent.radius
                color: root.level === "ok" ? Colors.primary : root.tone
                Behavior on width {
                    enabled: BarLook.animDuration > 0
                    NumberAnimation {
                        duration: BarLook.animDuration / 2
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }
        Text {
            objectName: "usageSlotText"
            text: root.text
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-4)
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
