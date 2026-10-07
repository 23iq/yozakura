import QtQuick
import qs.config
import qs.modules.components.kit
import "../../widgets/dashboard/widgets"
import "../../widgets/dashboard/widgets/WidgetRegistry.js" as WidgetRegistry
import "ClockPanelLayout.js" as ClockPanelLayout

// The "bento" clock popup (bar.moduleOptions.clock.panelStyle): the header
// (time, date, the pencil) over a bento grid of the shared widget registry
// (weather, pomodoro, agenda, world clocks by default; any widget can be
// added). The layout is bar.moduleOptions.clock.panel.cells, edited in place
// like the dashboard.
Column {
    id: root

    property date now: new Date()
    property bool use12h: false
    property bool editing: false

    readonly property var savedCells: Config.bar.moduleOptions?.clock?.panel?.cells ?? []
    readonly property var registry: ({
            "ids": WidgetRegistry.ids,
            "byId": WidgetRegistry.byId,
            "defaultGrid": ClockPanelLayout.defaultGrid
        })

    width: bento.implicitWidth
    spacing: Look.groupGap

    // leaving the popup ends edit mode (BentoView saves on the way out)
    onVisibleChanged: if (!visible)
        root.editing = false

    Group {
        width: root.width

        ClockPanelHeader {
            width: parent.width
            now: root.now
            use12h: root.use12h
            editable: true
            editing: root.editing
            onEditToggled: root.editing = !root.editing
        }
    }

    BentoView {
        id: bento
        objectName: "clockPanelBento"
        width: root.width
        height: implicitHeight
        registry: root.registry
        cols: ClockPanelLayout.COLS
        cells: root.savedCells
        editing: root.editing
        onEditingRequested: on => root.editing = on
        onCommit: cells => Config.bar.moduleOptions = ClockPanelLayout.withCells(Config.bar.moduleOptions, cells)
    }
}
