pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/ai/ModelInfo.js" as ModelInfo

// Small capability pills of a model: tools, vision, thinking, context size
// ("200k"), or "chat only" when the model cannot call tools.
RowLayout {
    id: root

    property var info: null

    readonly property var badges: ModelInfo.badges(info)
    readonly property var glyphs: ({
            tools: Icons.wrench,
            chatOnly: Icons.chatDots,
            vision: Icons.eye,
            thinking: Icons.brain,
            context: Icons.stack
        })

    spacing: 4
    visible: badges.length > 0

    Repeater {
        model: root.badges
        delegate: StyledRect {
            id: badge
            required property var modelData
            readonly property string label: modelData.kind === "context" ? modelData.text : (modelData.kind === "chatOnly" ? I18n.t("ai.badge_chat_only") : "")
            objectName: "badge_" + modelData.kind
            implicitHeight: badgeRow.implicitHeight + 4
            implicitWidth: badgeRow.implicitWidth + (label ? 10 : 8)
            radius: height / 2
            variant: modelData.kind === "chatOnly" ? "internalbg" : "common"
            HoverHandler {
                id: badgeHover
            }
            StyledToolTip {
                tooltipText: I18n.t("ai.badge_" + badge.modelData.kind)
                show: badgeHover.hovered
            }
            RowLayout {
                id: badgeRow
                anchors.centerIn: parent
                spacing: 3
                Text {
                    text: root.glyphs[badge.modelData.kind] || ""
                    font.family: Icons.font
                    font.pixelSize: BarLook.font(-5)
                    color: badge.modelData.kind === "chatOnly" ? Colors.outline : Colors.overSurfaceVariant
                }
                Text {
                    visible: badge.label.length > 0
                    text: badge.label
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-5)
                    color: badge.modelData.kind === "chatOnly" ? Colors.outline : Colors.overSurfaceVariant
                }
            }
        }
    }
}
