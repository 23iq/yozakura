import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.bar.activities
import qs.modules.widgets.defaultview.activities
import "../../../services/timers/TimerFormat.js" as TimerFormat

// One timer (TimerFormat.timerRows shape): ring with time left, name and
// state; pause/resume, +1 min, reset, cancel. A ringing timer offers
// +5 min (snooze) and Stop instead.
Item {
    id: row

    property var timer: null
    property real unit: 4

    readonly property var t: row.timer || ({})
    readonly property bool ringing: !!row.t.ringing
    readonly property bool running: row.t.state === "running"
    readonly property color accent: row.ringing ? Colors.error : (row.running ? Colors.primary : Colors.outline)
    readonly property real iconSize: Math.round(Styling.fontSize(6))

    implicitHeight: Math.max(row.iconSize * 1.2, textColumn.implicitHeight, buttons.implicitHeight) + row.unit * 2

    ActivityIndicator {
        id: indicator
        anchors.verticalCenter: parent.verticalCenter
        kind: row.ringing ? "dot" : "ring"
        icon: row.ringing ? Icons.alarm : (row.t.pomodoro ? Icons.countdown : Icons.timer)
        progress: row.ringing ? -1 : (row.t.progress === undefined ? -1 : row.t.progress)
        accent: row.accent
        size: Math.round(row.iconSize * 0.8)
    }

    Column {
        id: textColumn
        anchors.left: indicator.right
        anchors.leftMargin: row.unit * 2
        anchors.right: buttons.left
        anchors.rightMargin: row.unit * 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.ringing ? I18n.t("activities.pomodoro_done") : TimerFormat.clock(row.t.leftMs || 0)
            textFormat: Text.PlainText
            color: row.ringing ? Colors.error : Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(1)
            font.weight: Font.Bold
            font.features: ({
                    "tnum": 1
                })
        }
        Text {
            width: parent.width
            text: TimerFormat.timerTitle(row.t, I18n.t) + (row.t.state === "paused" ? "  ·  " + I18n.t("timers.paused") : "")
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
            objectName: "timerSnooze"
            visible: row.ringing
            icon: Icons.clockCounterClockwise
            tooltip: I18n.t("timers.action.snooze")
            onClicked: TimersService.add(row.t.id, "5m")
        }
        NotchIconButton {
            objectName: "timerStop"
            visible: row.ringing
            icon: Icons.stop
            tone: "error"
            tooltip: I18n.t("timers.action.stop")
            onClicked: TimersService.dismiss(row.t.id)
        }
        NotchIconButton {
            objectName: "timerToggle"
            visible: !row.ringing
            icon: row.running ? Icons.pause : Icons.play
            tooltip: row.running ? I18n.t("timers.pause") : I18n.t("timers.resume")
            onClicked: TimersService.toggle(row.t.id)
        }
        NotchIconButton {
            objectName: "timerPlus"
            visible: !row.ringing
            icon: Icons.plus
            tooltip: I18n.t("timers.plus_minute")
            onClicked: TimersService.add(row.t.id, "+1m")
        }
        NotchIconButton {
            objectName: "timerReset"
            visible: !row.ringing
            icon: Icons.arrowCounterClockwise
            tooltip: I18n.t("timers.reset")
            onClicked: TimersService.reset(row.t.id)
        }
        NotchIconButton {
            objectName: "timerCancel"
            visible: !row.ringing
            icon: Icons.cancel
            tooltip: I18n.t("timers.cancel")
            onClicked: TimersService.cancel(row.t.id)
        }
    }
}
