pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit
import "../../services/ai/ContextMath.js" as ContextMath

// Context window meter of the composer strip: a thin bar and `62k/200k`,
// amber from ai.context.warnAt, red from criticalAt, details in a tooltip.
// HTTP chats get a Compact button once the window is filling up.
RowLayout {
    id: root
    objectName: "composerContext"

    property int used: 0
    property int window: 0
    property string source: ""
    property bool canCompact: false
    property bool compacting: false
    property bool agent: false

    signal compactRequested

    readonly property real fraction: ContextMath.fraction(used, window)
    readonly property string level: ContextMath.level(fraction, Config.ai.context.warnAt, Config.ai.context.criticalAt)
    readonly property color tone: level === "critical" ? Type.danger : (level === "warn" ? Colors.warning : Type.progress)

    spacing: Space.s

    Item {
        implicitWidth: meter.implicitWidth
        implicitHeight: meter.implicitHeight + Space.xs
        Layout.alignment: Qt.AlignVCenter
        HoverHandler {
            id: hover
        }
        RowLayout {
            id: meter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.s
            LevelMeter {
                objectName: "contextBar"
                Layout.preferredWidth: Space.xxl + Space.l
                Layout.preferredHeight: Space.xs
                level: root.fraction
                tone: root.tone
            }
            AiText {
                objectName: "contextLabel"
                role: "caption"
                text: ContextMath.label(root.used, root.window)
                font.features: {
                    "tnum": 1
                }
                color: root.level === "ok" ? Colors.outline : root.tone
            }
        }
        StyledToolTip {
            tooltipText: I18n.t("ai.context_window")
            desciription: I18n.t("ai.context_detail").arg(root.used.toLocaleString(Qt.locale(), "f", 0)).arg(root.window.toLocaleString(Qt.locale(), "f", 0)).arg(Math.round(root.fraction * 100)) + "\n" + I18n.t("ai.context_source." + (root.source || "table")) + (root.agent ? "\n" + I18n.t("ai.context_agent_compacts") : "")
            show: hover.hovered
        }
    }

    Chip {
        objectName: "composerCompact"
        visible: !root.agent && root.level !== "ok" && (root.canCompact || root.compacting)
        enabled: root.canCompact && !root.compacting
        dense: true
        icon: Icons.arrowsInSimple
        text: root.compacting ? I18n.t("ai.compacting") : I18n.t("ai.compact")
        danger: root.level === "critical"
        onClicked: root.compactRequested()
    }
}
