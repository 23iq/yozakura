pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import "../../widgets/dashboard/widgets"
import "../../widgets/dashboard/widgets/WidgetRegistry.js" as WidgetRegistry
import "ClockPanelLayout.js" as ClockPanelLayout

// The bar clock popup: a header (time, date, edit) over a bento grid of the
// shared widget registry (weather, pomodoro, agenda, world clocks by
// default; any widget can be added). The layout is
// bar.moduleOptions.clock.panel.cells, edited in place like the dashboard.
StyledRect {
    id: root

    property date now: new Date()
    property bool use12h: Config.bar.use12hFormat ?? false
    property bool editing: false

    readonly property var savedCells: Config.bar.moduleOptions?.clock?.panel?.cells ?? []
    readonly property var registry: ({
            "ids": WidgetRegistry.ids,
            "byId": WidgetRegistry.byId,
            "defaultGrid": ClockPanelLayout.defaultGrid
        })

    variant: "popup"
    enableShadow: false
    radius: Styling.radius(8)
    implicitWidth: content.implicitWidth + 2 * Metrics.padding
    implicitHeight: content.implicitHeight + 2 * Metrics.padding

    // leaving the popup ends edit mode (BentoView saves on the way out)
    onVisibleChanged: if (!visible)
        root.editing = false

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Metrics.padding
        spacing: Metrics.spacing

        ClockPanelHeader {
            Layout.fillWidth: true
            now: root.now
            use12h: root.use12h
            editing: root.editing
            onEditToggled: root.editing = !root.editing
        }

        BentoView {
            id: bento
            objectName: "clockPanelBento"
            Layout.fillWidth: true
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            registry: root.registry
            cols: ClockPanelLayout.COLS
            cells: root.savedCells
            editing: root.editing
            onEditingRequested: on => root.editing = on
            onCommit: cells => Config.bar.moduleOptions = ClockPanelLayout.withCells(Config.bar.moduleOptions, cells)
        }

        Loader {
            Layout.fillWidth: true
            active: WeatherService.debugMode
            visible: active
            sourceComponent: WeatherDebugPanel {}
        }
    }
}
