pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../../../../services/timers/TimerFormat.js" as TimerFormat

// Pomodoro bento widget (bar clock panel, dashboard): a view over the
// backend Pomodoro (timers.pomodoro in svc/timers, one source of truth with
// the notch, the CLI and the AI). Idle: work/break lengths
// (system.pomodoro.workTime / restTime, -/+ 1 min) and Start; running: time
// left of the phase, pause, -1/+1 min, reset, cancel. A narrow tile stacks
// the lengths and drops the -1/+1 buttons. The IPC target and the Spotify
// sync live in modules/bar/clock/PomodoroSync.qml (not tied to a tile).
Item {
    id: root

    property real cellW: Metrics.bentoCell
    property real cellH: Metrics.bentoCell
    property bool compact: false
    readonly property bool narrow: root.width < root.cellW * 1.5

    implicitHeight: content.implicitHeight + 2 * Metrics.spacing

    readonly property var pomo: TimersService.pomodoro
    readonly property bool active: root.pomo !== null
    readonly property bool running: root.active && root.pomo.state === "running"
    readonly property bool ringing: root.active && root.pomo.ringing
    readonly property bool workPhase: !root.active || (root.pomo.pomodoro && root.pomo.pomodoro.phase === "work")
    readonly property var cfg: Config.system.pomodoro

    function adjust(key, delta) {
        root.cfg[key] = Math.max(60, Math.min(key === "workTime" ? 14400 : 7200, root.cfg[key] + delta));
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Metrics.spacing
        spacing: Metrics.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: Icons.countdown
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(1)
                color: Styling.srItem("overprimary")
            }
            Text {
                Layout.fillWidth: true
                text: root.active ? (root.workPhase ? I18n.t("pomodoro.work_session") : I18n.t("pomodoro.rest_session")) : I18n.t("timers.pomodoro")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Bold
                color: Colors.overBackground
            }
            Text {
                visible: root.active && !!root.pomo.pomodoro
                text: root.active && root.pomo.pomodoro ? I18n.t("timers.round", root.pomo.pomodoro.round) : ""
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.outline
            }
        }

        // Big time: the phase left, or the work length when idle
        Text {
            objectName: "pomodoroTime"
            Layout.alignment: Qt.AlignHCenter
            text: root.ringing ? I18n.t("activities.pomodoro_done") : TimerFormat.clock(root.active ? root.pomo.leftMs : root.cfg.workTime * 1000)
            font.family: Config.theme.monoFont
            font.features: {
                "tnum": 1
            }
            font.pixelSize: Styling.fontSize(root.narrow ? 4 : 8)
            font.weight: Font.Bold
            color: root.ringing ? Colors.error : Colors.overBackground
        }

        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            StyledRect {
                variant: "primary"
                height: parent.height
                radius: parent.radius
                width: parent.width * (root.active ? (root.pomo.progress ?? 0) : 1)
                Behavior on width {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.morph.duration
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }

        // Idle: lengths (stacked on a narrow tile)
        GridLayout {
            visible: !root.active
            Layout.fillWidth: true
            columns: root.narrow ? 1 : 2
            rowSpacing: Metrics.spacing / 2
            columnSpacing: Metrics.spacing
            LengthStepper {
                Layout.fillWidth: true
                label: I18n.t("pomodoro.work_session")
                seconds: root.cfg.workTime
                onStep: delta => root.adjust("workTime", delta)
            }
            LengthStepper {
                Layout.fillWidth: true
                label: I18n.t("pomodoro.rest_session")
                seconds: root.cfg.restTime
                onStep: delta => root.adjust("restTime", delta)
            }
        }

        // Running: adjust, main button, reset/cancel
        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacing

            PomoButton {
                visible: root.active && !root.ringing && !root.narrow
                text: I18n.t("pomodoro.minus_1m")
                onClicked: TimersService.add(root.pomo.id, "-1m")
            }
            PomoButton {
                objectName: "pomodoroMain"
                Layout.fillWidth: true
                primary: true
                text: root.ringing ? I18n.t("pomodoro.stop_alarm") : (root.running ? I18n.t("pomodoro.pause") : (root.active ? I18n.t("pomodoro.resume") : I18n.t("pomodoro.start_work")))
                onClicked: {
                    if (root.ringing)
                        TimersService.dismiss(root.pomo.id);
                    else if (root.active)
                        TimersService.toggle(root.pomo.id);
                    else
                        TimersService.startPomodoro(root.cfg.workTime, root.cfg.restTime);
                }
            }
            PomoButton {
                visible: root.active && !root.ringing && !root.narrow
                text: I18n.t("pomodoro.plus_1m")
                onClicked: TimersService.add(root.pomo.id, "+1m")
            }
            PomoButton {
                visible: root.active
                icon: Icons.cancel
                onClicked: TimersService.cancel(root.pomo.id)
            }
        }

        GridLayout {
            visible: !root.compact
            Layout.alignment: Qt.AlignHCenter
            columns: root.narrow ? 1 : 2
            columnSpacing: Metrics.spacing * 2
            rowSpacing: Metrics.spacing / 2
            PomoSwitch {
                text: I18n.t("common.auto")
                checked: root.cfg.autoStart
                onToggled: root.cfg.autoStart = !root.cfg.autoStart
            }
            PomoSwitch {
                text: I18n.t("pomodoro.sync_spotify")
                checked: root.cfg.syncSpotify
                onToggled: root.cfg.syncSpotify = !root.cfg.syncSpotify
            }
        }
    }

    component LengthStepper: StyledRect {
        id: stepper
        property string label: ""
        property int seconds: 0
        signal step(int delta)
        variant: "common"
        implicitHeight: 36
        radius: Styling.radius(-4)
        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            PomoButton {
                text: "−"
                implicitWidth: 26
                implicitHeight: 26
                onClicked: stepper.step(-60)
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: stepper.label + " " + TimerFormat.compact(stepper.seconds * 1000)
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overBackground
            }
            PomoButton {
                text: "+"
                implicitWidth: 26
                implicitHeight: 26
                onClicked: stepper.step(60)
            }
        }
    }

    component PomoButton: StyledRect {
        id: btn
        property string text: ""
        property string icon: ""
        property bool primary: false
        signal clicked
        variant: btn.primary ? "primary" : (area.containsMouse ? "focus" : "common")
        implicitWidth: 44
        implicitHeight: 40
        radius: Styling.radius(-4)
        Text {
            anchors.centerIn: parent
            text: btn.icon !== "" ? btn.icon : btn.text
            font.family: btn.icon !== "" ? Icons.font : Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: btn.primary ? Font.Black : Font.Normal
            color: btn.item
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component PomoSwitch: Item {
        id: sw
        property string text: ""
        property bool checked: false
        signal toggled
        implicitWidth: swRow.implicitWidth
        implicitHeight: swRow.implicitHeight
        RowLayout {
            id: swRow
            spacing: 8
            Text {
                text: sw.text
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.outline
            }
            StyledRect {
                variant: sw.checked ? "primary" : "common"
                Layout.preferredWidth: 36
                Layout.preferredHeight: 20
                radius: 10
                StyledRect {
                    variant: "internalbg"
                    x: sw.checked ? parent.width - width - 2 : 2
                    y: 2
                    width: 16
                    height: 16
                    radius: 8
                    Behavior on x {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Motion.morph.duration
                            easing.type: Motion.morph.easing
                        }
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }
}
