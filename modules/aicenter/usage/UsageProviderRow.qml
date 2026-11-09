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

// One provider of the Usage screen: icon, name, requests and tokens, a
// per-day sparkline and the cost; click to list its models.
ColumnLayout {
    id: root

    property var row: ({})          // summary row {key, requests, inputTokens, ...}
    property var models: []         // model rows of this provider
    property var series: []         // tokens per day (sparkline)
    property var costOpts: ({})
    property bool expanded: false

    readonly property string icon: UsageFormat.providerIcon(row.key)

    spacing: Space.xs / 2

    StyledRect {
        objectName: "usageProvider_" + root.row.key
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + 2 * Space.s
        radius: Look.radius("control")
        variant: hover.hovered || root.expanded ? "common" : "transparent"
        enableBorder: false

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.expanded = !root.expanded
        }

        RowLayout {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Space.s
            anchors.rightMargin: Space.s
            spacing: Space.s

            StyledRect {
                Layout.preferredWidth: Space.controlXS
                Layout.preferredHeight: Space.controlXS
                radius: Look.radius("round", height)
                variant: "internalbg"
                enableBorder: false
                Image {
                    anchors.centerIn: parent
                    visible: root.icon.length > 0
                    source: root.icon ? Qt.resolvedUrl("../../../assets/aiproviders/" + root.icon) : ""
                    sourceSize: Qt.size(16, 16)
                }
                AiText {
                    role: "caption"
                    anchors.centerIn: parent
                    visible: root.icon.length === 0
                    text: UsageFormat.providerLabel(root.row.key).charAt(0).toUpperCase()
                    font.weight: Font.DemiBold
                    color: Type.secondary
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Space.hairline
                AiText {
                    role: "secondary"
                    Layout.fillWidth: true
                    text: UsageFormat.providerLabel(root.row.key)
                    elide: Text.ElideRight
                    color: Type.text
                }
                AiText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: I18n.t("ai.usage.requests").arg(root.row.requests || 0) + "  ·  " + I18n.t("ai.usage.tokens_in_out").arg(UsageFormat.tokens(root.row.inputTokens)).arg(UsageFormat.tokens(root.row.outputTokens))
                    elide: Text.ElideRight
                }
            }
            UsageSparkline {
                visible: (root.series || []).length > 1
                series: root.series
                Layout.alignment: Qt.AlignVCenter
            }
            AiText {
                objectName: "usageProviderCost"
                role: "secondary"
                text: UsageFormat.totalsCost(root.row, root.costOpts) || "—"
                font.features: {
                    "tnum": 1
                }
                color: Type.text
            }
            Icon {
                role: "caption"
                tone: "muted"
                icon: Icons.caretDown
                rotation: root.expanded ? 180 : 0
                size: BarLook.size("caption")
                Behavior on rotation {
                    enabled: BarLook.animDuration > 0
                    NumberAnimation {
                        duration: BarLook.animDuration / 3
                    }
                }
            }
        }
    }

    Repeater {
        model: root.expanded ? root.models : []
        delegate: RowLayout {
            id: modelRow
            required property var modelData
            Layout.fillWidth: true
            Layout.leftMargin: Space.xxl + Space.l
            Layout.rightMargin: Space.xxl
            spacing: Space.s
            AiText {
                mono: true
                role: "caption"
                Layout.fillWidth: true
                text: modelRow.modelData.key || I18n.t("ai.model_default")
                elide: Text.ElideMiddle
                color: Type.secondary
            }
            AiText {
                role: "caption"
                text: UsageFormat.tokens((modelRow.modelData.inputTokens || 0) + (modelRow.modelData.outputTokens || 0))
            }
            AiText {
                role: "caption"
                Layout.preferredWidth: 72
                horizontalAlignment: Text.AlignRight
                text: UsageFormat.totalsCost(modelRow.modelData, root.costOpts) || "—"
                font.features: {
                    "tnum": 1
                }
                color: Type.secondary
            }
        }
    }
}
