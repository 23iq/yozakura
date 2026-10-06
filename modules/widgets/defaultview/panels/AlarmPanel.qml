pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.widgets.defaultview.activities
import "../../../services/timers/TimerFormat.js" as TimerFormat

// Notch panel "alarm" (NotchPanels.js: auto), open while a timer rings
// (system.timers.alarmPanel): a pulsing alarm badge, what finished and
// Stop / +5 min. It goes away once nothing rings.
NotchPanel {
    id: panel

    readonly property var ringing: TimersService.ringingTimers
    readonly property var first: panel.ringing.length > 0 ? panel.ringing[0] : null
    readonly property bool pulse: Config.system && Config.system.timers ? Config.system.timers.pulseOnFinish !== false : true
    readonly property real badgeSize: Math.round(Styling.fontSize(6) * 1.6)

    implicitHeight: panel.padding * 2 + Math.max(badge.height, texts.implicitHeight, buttons.implicitHeight)

    StyledRect {
        id: badge
        variant: "primary"
        x: panel.padding
        y: panel.padding
        width: panel.badgeSize
        height: panel.badgeSize
        radius: width / 2
        enableShadow: true

        Text {
            anchors.centerIn: parent
            text: Icons.alarm
            font.family: Icons.font
            font.pixelSize: Math.round(panel.badgeSize * 0.5)
            color: badge.item
        }

        SequentialAnimation on scale {
            running: panel.pulse && panel.revealed && Config.animDuration > 0
            loops: Animation.Infinite
            NumberAnimation {
                to: 1.12
                duration: 520
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                to: 1
                duration: 680
                easing.type: Easing.InOutQuad
            }
        }
    }

    Column {
        id: texts
        anchors.left: badge.right
        anchors.leftMargin: panel.unit * 3
        anchors.right: buttons.left
        anchors.rightMargin: panel.unit * 2
        anchors.verticalCenter: badge.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: I18n.t("activities.pomodoro_done")
            textFormat: Text.PlainText
            color: Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(1)
            font.weight: Font.Bold
        }
        Text {
            objectName: "alarmNames"
            width: parent.width
            text: panel.ringing.map(t => TimerFormat.timerTitle(t, I18n.t)).join(", ")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
        }
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: panel.padding
        anchors.verticalCenter: badge.verticalCenter
        spacing: panel.unit * 2

        NotchIconButton {
            objectName: "alarmSnooze"
            visible: panel.ringing.length === 1
            icon: Icons.clockCounterClockwise
            tooltip: I18n.t("timers.action.snooze")
            onClicked: TimersService.add(panel.first.id, "5m")
        }
        NotchIconButton {
            objectName: "alarmStop"
            icon: Icons.stop
            tone: "error"
            tooltip: panel.ringing.length > 1 ? I18n.t("timers.stop_all") : I18n.t("timers.action.stop")
            onClicked: TimersService.dismiss(panel.ringing.length > 1 ? "" : panel.first.id)
        }
    }
}
