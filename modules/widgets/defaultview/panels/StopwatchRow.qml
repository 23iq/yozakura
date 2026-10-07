pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../../services/timers/TimerFormat.js" as TimerFormat

// The stopwatch: a ListRow (elapsed, state; lap / pause-resume / reset)
// over the last laps (newest first, split + total) in caption figures.
Column {
    id: row

    property real unit: Space.xs
    property int maxLaps: 3

    readonly property var sw: TimersService.stopwatch
    readonly property bool running: row.sw.state === "running"
    readonly property var laps: TimerFormat.laps(row.sw).slice(0, row.maxLaps)
    // Laps line up with the row's text column
    readonly property real textX: Space.s + Space.controlS + Space.m

    spacing: 0

    ListRow {
        id: head
        objectName: "stopwatchElapsed"
        width: parent.width
        tabular: true
        title: TimerFormat.clock(TimersService.stopwatchMs, false)
        subtitle: I18n.t("timers.stopwatch") + (row.sw.state === "paused" ? " · " + I18n.t("timers.paused") : "")

        leading: Component {
            Art {
                width: Space.controlS
                height: Space.controlS
                icon: Icons.watch
            }
        }
        trailing: Component {
            Row {
                spacing: Space.xs

                IconButton {
                    objectName: "stopwatchLap"
                    size: "s"
                    visible: row.running
                    icon: Icons.listChecks
                    Accessible.name: I18n.t("timers.lap")
                    onClicked: TimersService.stopwatchAction("lap")
                }
                IconButton {
                    objectName: "stopwatchToggle"
                    size: "s"
                    icon: row.running ? Icons.pause : Icons.play
                    Accessible.name: row.running ? I18n.t("timers.pause") : I18n.t("timers.resume")
                    onClicked: TimersService.stopwatchAction("toggle")
                }
                IconButton {
                    objectName: "stopwatchReset"
                    size: "s"
                    icon: Icons.arrowCounterClockwise
                    Accessible.name: I18n.t("timers.reset")
                    onClicked: TimersService.stopwatchAction("reset")
                }
            }
        }
    }

    Repeater {
        model: row.laps
        delegate: KitText {
            required property var modelData
            x: row.textX
            width: row.width - x
            role: "caption"
            tabular: true
            text: I18n.t("timers.lap_n", modelData.n) + "   " + TimerFormat.clock(modelData.splitMs, false) + "   ·   " + TimerFormat.clock(modelData.totalMs, false)
        }
    }
}
