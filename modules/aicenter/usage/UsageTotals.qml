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

// Headline of the Usage screen: total cost of the range, tokens in/out,
// requests and (week/month) a per-day sparkline of every provider.
StyledRect {
    id: root

    property var totals: ({})
    property var costOpts: ({})
    property var series: []

    readonly property string costText: UsageFormat.totalsCost(totals, costOpts)

    variant: "common"
    radius: Look.radius("surface")
    enableBorder: false
    implicitHeight: content.implicitHeight + 2 * Space.m

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Space.l
        spacing: Space.m

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Space.xs / 2
            AiText {
                objectName: "usageTotalCost"
                role: "title"
                text: root.costText || UsageFormat.tokens((root.totals.inputTokens || 0) + (root.totals.outputTokens || 0))
                font.weight: Font.DemiBold
                font.features: {
                    "tnum": 1
                }
            }
            AiText {
                role: "caption"
                Layout.fillWidth: true
                text: I18n.t("ai.usage.tokens_in_out").arg(UsageFormat.tokens(root.totals.inputTokens)).arg(UsageFormat.tokens(root.totals.outputTokens)) + "  ·  " + I18n.t("ai.usage.requests").arg(root.totals.requests || 0) + ((root.totals.cachedTokens || 0) > 0 ? "  ·  " + I18n.t("ai.usage.cached").arg(UsageFormat.tokens(root.totals.cachedTokens)) : "")
                wrapMode: Text.Wrap
                color: Type.secondary
            }
        }
        UsageSparkline {
            visible: (root.series || []).length > 1
            series: root.series
            implicitWidth: Space.controlL + Space.l
            implicitHeight: Space.xxl
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
