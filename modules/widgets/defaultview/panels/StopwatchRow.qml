pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.widgets.defaultview.activities
import "../../../services/timers/TimerFormat.js" as TimerFormat

// The stopwatch: elapsed time, lap / pause-resume / reset, and the last
// laps (newest first, split + total).
Item {
    id: row

    property real unit: 4
    property int maxLaps: 3

    readonly property var sw: TimersService.stopwatch
    readonly property bool running: row.sw.state === "running"
    readonly property var laps: TimerFormat.laps(row.sw).slice(0, row.maxLaps)
    readonly property real iconSize: Math.round(Styling.fontSize(6))

    implicitHeight: head.height + (lapColumn.visible ? lapColumn.implicitHeight + row.unit : 0) + row.unit * 2

    Item {
        id: head
        y: row.unit
        width: parent.width
        height: Math.max(row.iconSize, textColumn.implicitHeight, buttons.implicitHeight)

        Text {
            id: glyph
            width: Math.round(row.iconSize * 0.96)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Icons.watch
            font.family: Icons.font
            font.pixelSize: Math.round(row.iconSize * 0.7)
            color: row.running ? Colors.primary : Colors.outline
        }

        Column {
            id: textColumn
            anchors.left: glyph.right
            anchors.leftMargin: row.unit * 2
            anchors.right: buttons.left
            anchors.rightMargin: row.unit * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                objectName: "stopwatchElapsed"
                width: parent.width
                text: TimerFormat.clock(TimersService.stopwatchMs, false)
                textFormat: Text.PlainText
                color: Colors.overBackground
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(1)
                font.weight: Font.Bold
                font.features: ({
                        "tnum": 1
                    })
            }
            Text {
                width: parent.width
                text: I18n.t("timers.stopwatch") + (row.sw.state === "paused" ? "  ·  " + I18n.t("timers.paused") : "")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Colors.overSurfaceVariant
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
            }
        }

        Row {
            id: buttons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: row.unit

            NotchIconButton {
                objectName: "stopwatchLap"
                visible: row.running
                icon: Icons.listChecks
                tooltip: I18n.t("timers.lap")
                onClicked: TimersService.stopwatchAction("lap")
            }
            NotchIconButton {
                objectName: "stopwatchToggle"
                icon: row.running ? Icons.pause : Icons.play
                tooltip: row.running ? I18n.t("timers.pause") : I18n.t("timers.resume")
                onClicked: TimersService.stopwatchAction("toggle")
            }
            NotchIconButton {
                objectName: "stopwatchReset"
                icon: Icons.arrowCounterClockwise
                tooltip: I18n.t("timers.reset")
                onClicked: TimersService.stopwatchAction("reset")
            }
        }
    }

    Column {
        id: lapColumn
        anchors.top: head.bottom
        anchors.topMargin: row.unit
        x: Math.round(row.iconSize * 0.96) + row.unit * 2
        width: parent.width - x
        visible: row.laps.length > 0
        spacing: 1

        Repeater {
            model: row.laps
            delegate: Text {
                required property var modelData
                width: lapColumn.width
                text: I18n.t("timers.lap_n", modelData.n) + "   " + TimerFormat.clock(modelData.splitMs, false) + "   ·   " + TimerFormat.clock(modelData.totalMs, false)
                textFormat: Text.PlainText
                color: Colors.overSurfaceVariant
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.features: ({
                        "tnum": 1
                    })
            }
        }
    }
}
