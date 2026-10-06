pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/ai/UsageFormat.js" as UsageFormat

// One subscription window: "Claude Code · 5-hour window   34%", a bar
// (amber/red from ai.usage.warnAt/criticalAt) and the reset countdown.
StyledRect {
    id: root

    // {provider, id, percent, resetsAt, source}
    property var win: ({})
    property var units: ({})
    property double now: Date.now()

    readonly property string level: UsageFormat.level(win.percent || 0, Config.ai.usage.warnAt, Config.ai.usage.criticalAt)
    readonly property color tone: level === "critical" ? Colors.error : (level === "warn" ? Colors.warning : Colors.primary)
    readonly property double msLeft: UsageFormat.msUntil(win.resetsAt, now)

    variant: "common"
    radius: Styling.radius(-2)
    enableBorder: false
    implicitHeight: column.implicitHeight + 20

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: UsageFormat.providerLabel(root.win.provider) + "  ·  " + (UsageFormat.windowKey(root.win.id) ? I18n.t(UsageFormat.windowKey(root.win.id)) : root.win.id)
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-2)
                color: Colors.overSurface
            }
            Text {
                objectName: "usageLimitPercent"
                text: Math.round(root.win.percent || 0) + "%"
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-2)
                font.weight: Font.DemiBold
                font.features: {
                    "tnum": 1
                }
                color: root.level === "ok" ? Colors.overSurface : root.tone
            }
        }
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            variant: "internalbg"
            radius: 3
            enableBorder: false
            // Fill of the window bar.
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, (root.win.percent || 0) / 100))
                height: parent.height
                radius: parent.radius
                color: root.tone
                Behavior on width {
                    enabled: BarLook.animDuration > 0
                    NumberAnimation {
                        duration: BarLook.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.msLeft > 0 ? I18n.t("ai.usage.resets_in").arg(UsageFormat.duration(root.msLeft, root.units)) : ""
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-4)
            color: Colors.outline
        }
    }
}
