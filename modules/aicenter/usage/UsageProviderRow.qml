pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
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

    spacing: 2

    StyledRect {
        objectName: "usageProvider_" + root.row.key
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + 16
        radius: Styling.radius(-2)
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
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            StyledRect {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                variant: "internalbg"
                enableBorder: false
                Image {
                    anchors.centerIn: parent
                    visible: root.icon.length > 0
                    source: root.icon ? Qt.resolvedUrl("../../../assets/aiproviders/" + root.icon) : ""
                    sourceSize: Qt.size(16, 16)
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.icon.length === 0
                    text: UsageFormat.providerLabel(root.row.key).charAt(0).toUpperCase()
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-3)
                    font.weight: Font.DemiBold
                    color: Colors.overSurfaceVariant
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: UsageFormat.providerLabel(root.row.key)
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-1)
                    color: Colors.overSurface
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("ai.usage.requests").arg(root.row.requests || 0) + "  ·  " + I18n.t("ai.usage.tokens_in_out").arg(UsageFormat.tokens(root.row.inputTokens)).arg(UsageFormat.tokens(root.row.outputTokens))
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-4)
                    color: Colors.outline
                }
            }
            UsageSparkline {
                visible: (root.series || []).length > 1
                values: root.series
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                objectName: "usageProviderCost"
                text: UsageFormat.totalsCost(root.row, root.costOpts) || "—"
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-1)
                font.features: {
                    "tnum": 1
                }
                color: Colors.overSurface
            }
            Text {
                text: Icons.caretDown
                rotation: root.expanded ? 180 : 0
                font.family: Icons.font
                font.pixelSize: BarLook.font(-5)
                color: Colors.outline
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
            Layout.leftMargin: 48
            Layout.rightMargin: 34
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: modelRow.modelData.key || I18n.t("ai.model_default")
                elide: Text.ElideMiddle
                font.family: Config.theme.monoFont
                font.pixelSize: BarLook.font(-4)
                color: Colors.overSurfaceVariant
            }
            Text {
                text: UsageFormat.tokens((modelRow.modelData.inputTokens || 0) + (modelRow.modelData.outputTokens || 0))
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-4)
                color: Colors.outline
            }
            Text {
                Layout.preferredWidth: 72
                horizontalAlignment: Text.AlignRight
                text: UsageFormat.totalsCost(modelRow.modelData, root.costOpts) || "—"
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-4)
                font.features: {
                    "tnum": 1
                }
                color: Colors.overSurfaceVariant
            }
        }
    }
}
