pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.header
import "../../services/ai/ModelInfo.js" as ModelInfo

// Models a local server reported in its test, with capabilities (Ollama
// probe: tools, vision, thinking, context size; "chat only" without tools).
ColumnLayout {
    id: root

    property var models: []
    property int limit: 8

    spacing: Space.xs
    visible: models.length > 0

    AiText {
        role: "caption"
        text: I18n.t("ai.connect.local_models")
        font.weight: Font.Medium
    }
    Repeater {
        model: root.models.slice(0, root.limit)
        delegate: StyledRect {
            id: row
            required property var modelData
            objectName: "probeModel_" + modelData.id
            Layout.fillWidth: true
            implicitHeight: Space.controlS
            radius: Look.radius("small")
            variant: "internalbg"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Space.s
                anchors.rightMargin: Space.s
                spacing: Space.s
                AiText {
                    mono: true
                    role: "caption"
                    Layout.fillWidth: true
                    text: row.modelData.name || row.modelData.id
                    elide: Text.ElideRight
                    color: Type.text
                }
                AiText {
                    role: "caption"
                    visible: !!(row.modelData.probe && row.modelData.probe.sizeLabel)
                    text: row.modelData.probe ? row.modelData.probe.sizeLabel || "" : ""
                }
                CapabilityBadges {
                    info: row.modelData.probe ? ModelInfo.fromOllama(row.modelData.probe) : null
                }
            }
        }
    }
    AiText {
        role: "caption"
        visible: root.models.length > root.limit
        text: I18n.t("ai.connect.more_models").arg(root.models.length - root.limit)
    }
}
