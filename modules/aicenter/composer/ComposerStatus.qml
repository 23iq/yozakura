pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/ai/Providers.js" as Providers

// Strip above the composer: `◆ engine · model ▾` (opens the model picker),
// `· effort ▾` (EffortChip, inline selector), agent status, the context
// window meter (ContextMeter, Compact button), session cost (costText) and
// the subscription limit (limitFraction 0..1 + limitText). Each item can be
// hidden in the settings (ai.strip.*).
RowLayout {
    id: root

    property int contextUsed: 0
    property int contextWindow: 0
    property string contextSource: ""
    property bool canCompact: false
    property bool compacting: false
    property string costText: ""
    property real limitFraction: -1
    property string limitText: ""

    signal pickRequested
    signal compactRequested

    readonly property var model: Ai.currentModel
    readonly property bool isAgent: model !== null && model.kind === "agent"
    readonly property var settings: Ai.agentSettings || ({})
    readonly property string engineLabel: !model ? I18n.t("ai.choose_model") : (isAgent ? model.name : (Providers.provider(model.provider).label || model.provider))
    readonly property var parts: !model ? [] : (isAgent ? [settings.model || I18n.t("ai.model_default")] : [model.name])
    readonly property string agentStatus: Ai.activeAgent ? Ai.activeAgent.status : ""

    spacing: 8

    StyledRect {
        objectName: "composerEngine"
        visible: Config.ai.strip.engine !== false
        // Shrinks (eliding the label) before the right-hand items.
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth
        implicitWidth: engineRow.implicitWidth + 16
        implicitHeight: engineRow.implicitHeight + 8
        radius: Styling.radius(-4)
        variant: engineHover.hovered ? "common" : "transparent"
        HoverHandler {
            id: engineHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.pickRequested()
        }
        RowLayout {
            id: engineRow
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 16)
            spacing: 6
            Text {
                text: Icons.sparkle
                font.family: Icons.font
                font.pixelSize: BarLook.font(-3)
                color: root.model ? Colors.primary : Colors.outline
            }
            Text {
                Layout.fillWidth: true
                text: [root.engineLabel].concat(root.parts.filter(p => p)).join("  ·  ")
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-3)
                color: Colors.overSurfaceVariant
            }
            Text {
                text: Icons.caretDown
                font.family: Icons.font
                font.pixelSize: BarLook.font(-5)
                color: Colors.outline
            }
        }
    }

    EffortChip {
        Layout.leftMargin: -6
    }

    StatusDot {
        visible: root.agentStatus === "waiting" || root.agentStatus === "running" || root.agentStatus === "starting"
        status: root.agentStatus || "idle"
    }
    Text {
        visible: root.agentStatus === "waiting"
        text: I18n.t("ai.status_waiting")
        font.family: Config.theme.font
        font.pixelSize: BarLook.font(-4)
        color: Colors.warning
    }

    Item {
        Layout.fillWidth: true
    }

    ContextMeter {
        visible: Config.ai.strip.context !== false && root.contextWindow > 0
        used: root.contextUsed
        window: root.contextWindow
        source: root.contextSource
        agent: root.isAgent
        canCompact: root.canCompact
        compacting: root.compacting
        onCompactRequested: root.compactRequested()
    }
    Text {
        objectName: "composerCost"
        visible: Config.ai.strip.cost !== false && root.costText.length > 0
        text: root.costText
        font.family: Config.theme.font
        font.pixelSize: BarLook.font(-4)
        color: Colors.outline
    }
    Text {
        objectName: "composerLimit"
        visible: Config.ai.strip.limit !== false && root.limitFraction >= 0
        text: root.limitText || Math.round(root.limitFraction * 100) + "%"
        font.family: Config.theme.font
        font.pixelSize: BarLook.font(-4)
        color: root.limitFraction >= 0.8 ? Colors.warning : Colors.outline
    }
}
