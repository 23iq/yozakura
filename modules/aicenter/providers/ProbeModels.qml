pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
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

    spacing: 4
    visible: models.length > 0

    Text {
        text: I18n.t("ai.connect.local_models")
        font.family: Config.theme.font
        font.pixelSize: BarLook.font(-2)
        font.weight: Font.Medium
        color: Colors.outline
    }
    Repeater {
        model: root.models.slice(0, root.limit)
        delegate: StyledRect {
            id: row
            required property var modelData
            objectName: "probeModel_" + modelData.id
            Layout.fillWidth: true
            implicitHeight: 34
            radius: Styling.radius(-6)
            variant: "internalbg"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.name || row.modelData.id
                    elide: Text.ElideRight
                    font.family: Config.theme.monoFont
                    font.pixelSize: BarLook.mono(-2)
                    color: Colors.overSurface
                }
                Text {
                    visible: !!(row.modelData.probe && row.modelData.probe.sizeLabel)
                    text: row.modelData.probe ? row.modelData.probe.sizeLabel || "" : ""
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-3)
                    color: Colors.outline
                }
                CapabilityBadges {
                    info: row.modelData.probe ? ModelInfo.fromOllama(row.modelData.probe) : null
                }
            }
        }
    }
    Text {
        visible: root.models.length > root.limit
        text: I18n.t("ai.connect.more_models").arg(root.models.length - root.limit)
        font.family: Config.theme.font
        font.pixelSize: BarLook.font(-3)
        color: Colors.outline
    }
}
