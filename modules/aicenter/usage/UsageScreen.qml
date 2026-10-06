pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/ai/UsageFormat.js" as UsageFormat

// Usage screen of the AI bar: Today / Week / Month totals, one row per
// provider (models on expand, per-day sparkline) and the subscription
// windows with their reset countdowns. Data: UsageService (usage.summary,
// usage.limits); refreshed when shown, on range change and on new records.
StyledRect {
    id: root
    objectName: "usageScreen"

    property string range: Config.ai.usage.defaultRange || "today"
    property var providers: null    // summary groupBy provider
    property var models: null       // summary groupBy model
    property var days: null         // summary groupBy provider_day
    property bool loading: false

    signal closeRequested

    readonly property var hidden: Config.ai.usage.hiddenProviders || []
    readonly property var costOpts: ({
            style: Config.ai.usage.currencyStyle || "symbol",
            decimals: Config.ai.usage.decimals || 2
        })
    readonly property var rows: UsageFormat.visibleRows(providers ? providers.rows : [], hidden)
    readonly property var totals: UsageFormat.sumRows(rows)
    readonly property bool sparklines: Config.ai.usage.sparklines !== false && range !== "today"
    readonly property var dayKeys: days ? UsageFormat.days(days.from, days.to, UsageService.now) : []
    readonly property var windows: UsageFormat.windows(UsageService.limits).filter(w => !UsageFormat.isHidden(w.provider, hidden))
    readonly property var units: ({
            d: I18n.t("ai.usage.unit_d"),
            h: I18n.t("ai.usage.unit_h"),
            m: I18n.t("ai.usage.unit_m")
        })

    variant: "popup"
    radius: Styling.radius(0)

    function refresh() {
        if (!visible)
            return;
        const r = range;
        loading = true;
        UsageService.summary(r, "provider", res => {
            if (r !== root.range)
                return;
            root.providers = res;
            root.loading = false;
        });
        UsageService.summary(r, "model", res => {
            if (r === root.range)
                root.models = res;
        });
        if (sparklines)
            UsageService.summary(r, "provider_day", res => {
                if (r === root.range)
                    root.days = res;
            });
        else
            days = null;
    }

    onVisibleChanged: if (visible) {
        UsageService.start();
        UsageService.refreshInfo();
        refresh();
    }
    onRangeChanged: refresh()
    onSparklinesChanged: refresh()
    Connections {
        target: UsageService
        function onRevisionChanged() {
            Qt.callLater(root.refresh);
        }
    }
    Keys.onEscapePressed: root.closeRequested()

    // Keeps clicks and hovers from reaching the transcript underneath.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: Icons.chartBar
                font.family: Icons.font
                font.pixelSize: BarLook.font(1)
                color: Colors.primary
            }
            Text {
                Layout.fillWidth: true
                text: I18n.t("ai.usage.title")
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(1)
                font.weight: Font.DemiBold
                color: Colors.overSurface
            }
            UsageRangeTabs {
                range: root.range
                onPicked: r => root.range = r
            }
            IconButton {
                objectName: "usageClose"
                glyph: Icons.cancel
                tooltip: I18n.t("ai.close") + " (Esc)"
                onClicked: root.closeRequested()
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 10

                UsageTotals {
                    Layout.fillWidth: true
                    totals: root.totals
                    costOpts: root.costOpts
                    series: root.sparklines ? UsageFormat.series((root.days ? root.days.rows : []).filter(r => !UsageFormat.isHidden(r.provider, root.hidden)), "", root.dayKeys) : []
                }

                Text {
                    objectName: "usageEmpty"
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: !root.loading && root.rows.length === 0
                    text: I18n.t("ai.usage.empty")
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                    color: Colors.outline
                }

                Repeater {
                    model: root.rows
                    delegate: UsageProviderRow {
                        required property var modelData
                        Layout.fillWidth: true
                        row: modelData
                        models: UsageFormat.modelsOf(root.models ? root.models.rows : [], modelData.key)
                        series: root.sparklines ? UsageFormat.series(root.days ? root.days.rows : [], modelData.key, root.dayKeys) : []
                        costOpts: root.costOpts
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    text: I18n.t("ai.usage.subscriptions")
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-3)
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    color: Colors.outline
                }
                Text {
                    objectName: "usageNoLimits"
                    Layout.fillWidth: true
                    visible: root.windows.length === 0
                    text: I18n.t("ai.usage.no_limits")
                    wrapMode: Text.Wrap
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-3)
                    color: Colors.outline
                }
                Repeater {
                    model: root.windows
                    delegate: UsageLimitCard {
                        required property var modelData
                        Layout.fillWidth: true
                        win: modelData
                        units: root.units
                        now: UsageService.now
                    }
                }

                Text {
                    objectName: "usageFootnote"
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    text: I18n.t("ai.usage.footnote") + (UsageService.info.pricesOverride ? "  <a href=\"prices\">" + I18n.t("ai.usage.edit_prices") + "</a>" : "")
                    textFormat: Text.StyledText
                    linkColor: Colors.primary
                    wrapMode: Text.Wrap
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-4)
                    color: Colors.outline
                    onLinkActivated: UsageService.openPrices()
                    HoverHandler {
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }
    }
}
