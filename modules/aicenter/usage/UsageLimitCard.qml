pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
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
    readonly property color tone: level === "critical" ? Type.danger : (level === "warn" ? Colors.warning : Type.progress)
    readonly property double msLeft: UsageFormat.msUntil(win.resetsAt, now)

    variant: "common"
    radius: Look.radius("control")
    enableBorder: false
    implicitHeight: column.implicitHeight + 2 * Space.s

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Space.m
        spacing: Space.s

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.s
            AiText {
                role: "caption"
                Layout.fillWidth: true
                text: UsageFormat.providerLabel(root.win.provider) + "  ·  " + (UsageFormat.windowKey(root.win.id) ? I18n.t(UsageFormat.windowKey(root.win.id)) : root.win.id)
                elide: Text.ElideRight
                color: Type.text
            }
            AiText {
                objectName: "usageLimitPercent"
                role: "caption"
                text: Math.round(root.win.percent || 0) + "%"
                font.weight: Font.DemiBold
                font.features: {
                    "tnum": 1
                }
                color: root.level === "ok" ? Colors.overSurface : root.tone
            }
        }
        LevelMeter {
            Layout.fillWidth: true
            Layout.preferredHeight: Space.s - Space.xs / 2
            level: (root.win.percent || 0) / 100
            tone: root.tone
        }
        AiText {
            role: "caption"
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.msLeft > 0 ? I18n.t("ai.usage.resets_in").arg(UsageFormat.duration(root.msLeft, root.units)) : ""
            elide: Text.ElideRight
        }
    }
}
