pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../../services/timers/TimerFormat.js" as TimerFormat

// Pomodoro card of the clock popup: a view over the backend Pomodoro
// (timers.pomodoro in svc/timers, one source of truth with the notch, the
// CLI and the AI). Idle: work/break lengths (system.pomodoro.workTime /
// restTime, -/+ 1 min) and Start; running: time left of the phase, pause,
// -1/+1 min, reset, cancel. The backend fires the phases and sends the
// notifications; TimersService pauses at each phase when autoStart is off.
Item {
    id: root
    implicitHeight: content.implicitHeight + 24
    width: 300

    readonly property var pomo: TimersService.pomodoro
    readonly property bool active: root.pomo !== null
    readonly property bool running: root.active && root.pomo.state === "running"
    readonly property bool ringing: root.active && root.pomo.ringing
    readonly property bool workPhase: !root.active || (root.pomo.pomodoro && root.pomo.pomodoro.phase === "work")
    readonly property var cfg: Config.system.pomodoro

    signal requestPopupOpen

    IpcHandler {
        target: "pomodoro"
        function check() {
            root.requestPopupOpen();
        }
        function stop() {
            if (root.active)
                TimersService.cancel(root.pomo.id);
        }
    }

    // system.pomodoro.syncSpotify: Spotify plays during work, pauses otherwise
    readonly property var spotifyPlayer: MprisController.filteredPlayers.find(p => p.dbusName.toLowerCase().includes("spotify")) || null
    readonly property bool spotifyShouldPlay: root.running && root.workPhase
    onSpotifyShouldPlayChanged: root.updateSpotify()
    function updateSpotify() {
        const s = root.spotifyPlayer;
        if (!root.cfg.syncSpotify || !s || !root.active)
            return;
        if (root.spotifyShouldPlay && !s.isPlaying && s.canPlay)
            s.play();
        else if (!root.spotifyShouldPlay && s.isPlaying && s.canPause)
            s.pause();
    }

    function adjust(key, delta) {
        root.cfg[key] = Math.max(60, Math.min(key === "workTime" ? 14400 : 7200, root.cfg[key] + delta));
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

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
            font.pixelSize: Styling.fontSize(8)
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
            }
        }

        // Idle: lengths
        RowLayout {
            visible: !root.active
            Layout.fillWidth: true
            spacing: 8
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
            spacing: 8

            PomoButton {
                visible: root.active && !root.ringing
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
                visible: root.active && !root.ringing
                text: I18n.t("pomodoro.plus_1m")
                onClicked: TimersService.add(root.pomo.id, "+1m")
            }
            PomoButton {
                visible: root.active
                icon: Icons.cancel
                onClicked: TimersService.cancel(root.pomo.id)
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            PomoSwitch {
                text: I18n.t("common.auto")
                checked: root.cfg.autoStart
                onToggled: root.cfg.autoStart = !root.cfg.autoStart
            }
            PomoSwitch {
                text: I18n.t("pomodoro.sync_spotify")
                checked: root.cfg.syncSpotify
                onToggled: {
                    root.cfg.syncSpotify = !root.cfg.syncSpotify;
                    root.updateSpotify();
                }
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
                            duration: 200
                            easing.type: Easing.OutQuart
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
