pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
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
    radius: Styling.radius(0)
    enableBorder: false
    implicitHeight: content.implicitHeight + 28

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 16
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                objectName: "usageTotalCost"
                text: root.costText || UsageFormat.tokens((root.totals.inputTokens || 0) + (root.totals.outputTokens || 0))
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(8)
                font.weight: Font.DemiBold
                font.features: {
                    "tnum": 1
                }
                color: Colors.overSurface
            }
            Text {
                Layout.fillWidth: true
                text: I18n.t("ai.usage.tokens_in_out").arg(UsageFormat.tokens(root.totals.inputTokens)).arg(UsageFormat.tokens(root.totals.outputTokens)) + "  ·  " + I18n.t("ai.usage.requests").arg(root.totals.requests || 0) + ((root.totals.cachedTokens || 0) > 0 ? "  ·  " + I18n.t("ai.usage.cached").arg(UsageFormat.tokens(root.totals.cachedTokens)) : "")
                wrapMode: Text.Wrap
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-3)
                color: Colors.overSurfaceVariant
            }
        }
        UsageSparkline {
            visible: (root.series || []).length > 1
            values: root.series
            barWidth: 6
            chartHeight: 32
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
