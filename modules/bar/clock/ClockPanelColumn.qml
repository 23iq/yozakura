import QtQuick
import qs.modules.services
import qs.modules.components.kit
import "../../widgets/dashboard/widgets/time"
import "../../widgets/dashboard/widgets/WidgetFormat.js" as WidgetFormat

// The "column" clock popup (bar.moduleOptions.clock.panelStyle): a narrow
// stack of groups. The time (display) and date with the weather now on the
// right and the day's details as a caption; the Pomodoro row; the world
// clocks ("city · offset · time"); the agenda, only when something is
// coming up. Groups take the visual language's look (ink hairlines, glass
// cards, tiles).
Column {
    id: root

    property date now: new Date()
    property bool use12h: false

    width: Space.rowHeight * 7
    spacing: Look.groupGap

    WorldClockSource {
        id: world
        running: root.visible
    }

    Group {
        width: root.width

        ClockPanelHeader {
            width: parent.width
            now: root.now
            use12h: root.use12h
        }
        KitText {
            objectName: "clockPanelDetails"
            width: parent.width
            visible: WeatherService.dataAvailable
            role: "caption"
            text: WidgetFormat.weatherDetails({
                "max": WeatherService.maxTemp,
                "min": WeatherService.minTemp,
                "rain": WeatherService.rainChance,
                "wind": WeatherService.windSpeed
            }, I18n.t)
        }
    }

    Group {
        width: root.width
        divider: true

        PomodoroRow {
            width: parent.width
        }
    }

    Group {
        objectName: "clockPanelWorld"
        width: root.width
        divider: true
        visible: world.rows.length > 0
        label: I18n.t("bento.label.world")

        WorldRows {
            width: parent.width
            rows: world.rows
        }
    }

    Group {
        objectName: "clockPanelAgenda"
        width: root.width
        divider: true
        visible: agenda.rows.length > 0
        label: I18n.t("bento.widget.agenda")

        AgendaRows {
            id: agenda
            width: parent.width
            limit: 3
        }
    }
}
