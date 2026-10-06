pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/ai/Providers.js" as Providers

// Strip above the composer: `◆ engine · model · effort ▾` (opens the model
// picker), agent status, and slots filled by later work: context window
// usage (contextUsed / contextWindow), session cost (costText) and the
// subscription limit (limitFraction 0..1 + limitText). Each item can be
// hidden in the settings (ai.strip.*).
RowLayout {
    id: root

    property int contextUsed: 0
    property int contextWindow: 0
    property string costText: ""
    property real limitFraction: -1
    property string limitText: ""

    signal pickRequested

    readonly property var model: Ai.currentModel
    readonly property bool isAgent: model !== null && model.kind === "agent"
    readonly property var settings: Ai.agentSettings || ({})
    readonly property string engineLabel: !model ? I18n.t("ai.choose_model") : (isAgent ? model.name : (Providers.provider(model.provider).label || model.provider))
    readonly property var parts: !model ? [] : (isAgent ? [settings.model || I18n.t("ai.model_default"), settings.effort || ""] : [model.name])
    readonly property string agentStatus: Ai.activeAgent ? Ai.activeAgent.status : ""
    readonly property real contextFraction: contextWindow > 0 ? Math.min(1, contextUsed / contextWindow) : 0

    spacing: 8

    function compact(n) {
        return n >= 1000 ? Math.round(n / 1000) + "k" : String(n);
    }

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

    RowLayout {
        objectName: "composerContext"
        visible: Config.ai.strip.context !== false && root.contextWindow > 0
        spacing: 6
        StyledRect {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 4
            variant: "internalbg"
            radius: 2
            // Fill of the meter (amber from 80 %).
            Rectangle {
                width: parent.width * root.contextFraction
                height: parent.height
                radius: parent.radius
                color: root.contextFraction >= 0.8 ? Colors.warning : Colors.primary
            }
        }
        Text {
            text: root.compact(root.contextUsed) + " / " + root.compact(root.contextWindow)
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-4)
            color: root.contextFraction >= 0.8 ? Colors.warning : Colors.outline
        }
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
