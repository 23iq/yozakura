pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.services
import qs.modules.components.kit
import "ClockPanelLayout.js" as ClockPanelLayout

// The bar clock popup: one kit Surface holding the style chosen in
// bar.moduleOptions.clock.panelStyle (ClockPanelLayout.styleOf):
//   column  narrow stack: time + weather, Pomodoro row, world, agenda
//   wide    time / weather | a large Pomodoro ring, world clocks inline
//   bento   the editable widget grid (bar.moduleOptions.clock.panel.cells)
// plus the weather preview controls while WeatherService.debugMode is on.
Surface {
    id: root

    property date now: new Date()
    property bool use12h: Config.bar.use12hFormat ?? false
    readonly property string panelStyle: ClockPanelLayout.styleOf(Config.bar.moduleOptions)

    Column {
        spacing: Look.groupGap

        Loader {
            id: body
            objectName: "clockPanelBody"
            sourceComponent: root.panelStyle === "wide" ? wide : (root.panelStyle === "bento" ? bento : column)
        }

        Loader {
            width: body.width
            active: WeatherService.debugMode
            visible: active
            sourceComponent: WeatherDebugPanel {}
        }
    }

    Component {
        id: column
        ClockPanelColumn {
            now: root.now
            use12h: root.use12h
        }
    }

    Component {
        id: wide
        ClockPanelWide {
            now: root.now
            use12h: root.use12h
        }
    }

    Component {
        id: bento
        ClockPanelBento {
            now: root.now
            use12h: root.use12h
        }
    }
}
