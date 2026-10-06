pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.aicenter.common
import qs.modules.aicenter.providers
import "../../services/tasks/TaskModel.js" as TaskModel

// The agents of a task, overlapping like avatars (best-of-N shows each run).
Row {
    id: root

    property var agents: []
    property int size: 16

    spacing: -Math.round(size / 4)

    Repeater {
        model: root.agents
        delegate: StyledRect {
            id: badge
            required property string modelData
            width: root.size + 4
            height: root.size + 4
            radius: height / 2
            variant: "internalbg"
            enableBorder: true
            HoverHandler {
                id: hover
            }
            ProviderIcon {
                anchors.centerIn: parent
                size: root.size - 4
                icon: TaskModel.agentIcon(badge.modelData)
                color: Colors.overSurface
                visible: icon.length > 0
            }
            Glyph {
                anchors.centerIn: parent
                visible: TaskModel.agentIcon(badge.modelData).length === 0
                text: Icons.terminal
                font.pixelSize: root.size - 5
            }
            StyledToolTip {
                tooltipText: TaskModel.agentLabel(badge.modelData, Ai.agents ? Ai.agents.agents : [])
                show: hover.hovered
            }
        }
    }
}
