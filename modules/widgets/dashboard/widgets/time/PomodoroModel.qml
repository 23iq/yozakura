import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import "../../../../services/timers/TimerFormat.js" as TimerFormat
import "../WidgetFormat.js" as WidgetFormat

// The Pomodoro as the views show it (the bento widget, the clock popup): a
// view over the backend Pomodoro (TimersService.pomodoro, one source of
// truth with the notch, the CLI and the AI) plus the idle lengths of
// system.pomodoro (workTime / restTime, seconds).
QtObject {
    id: root

    readonly property var pomo: TimersService.pomodoro
    readonly property var cfg: Config.system.pomodoro
    readonly property bool active: root.pomo !== null
    readonly property bool running: root.active && root.pomo.state === "running"
    readonly property bool ringing: root.active && !!root.pomo.ringing
    readonly property bool working: WidgetFormat.pomodoroPhase(root.pomo).phase === "work"
    // 0..1 of the phase; idle reads empty.
    readonly property real progress: root.active ? (root.pomo.progress ?? 0) : 0
    readonly property string timeText: root.ringing ? I18n.t("activities.pomodoro_done") : TimerFormat.clock(root.active ? root.pomo.leftMs : root.cfg.workTime * 1000)
    readonly property string label: WidgetFormat.pomodoroLabel(root.pomo, I18n.t)
    readonly property string lengths: I18n.t("clock.panel.lengths", TimerFormat.compact(root.cfg.workTime * 1000), TimerFormat.compact(root.cfg.restTime * 1000))
    readonly property string mainIcon: root.ringing ? Icons.check : (root.running ? Icons.pause : Icons.play)
    readonly property string mainText: root.ringing ? I18n.t("pomodoro.stop_alarm") : (root.running ? I18n.t("pomodoro.pause") : (root.active ? I18n.t("pomodoro.resume") : I18n.t("pomodoro.start_work")))

    // Start, pause / resume, or stop the alarm.
    function main() {
        if (root.ringing)
            TimersService.dismiss(root.pomo.id);
        else if (root.active)
            TimersService.toggle(root.pomo.id);
        else
            TimersService.startPomodoro(root.cfg.workTime, root.cfg.restTime);
    }

    function reset() {
        if (root.active)
            TimersService.reset(root.pomo.id);
    }

    function cancel() {
        if (root.active)
            TimersService.cancel(root.pomo.id);
    }

    // End the running phase now: the backend moves to the next one.
    function skip() {
        if (root.running)
            TimersService.add(root.pomo.id, "-" + Math.ceil((root.pomo.leftMs ?? 0) / 1000) + "s");
    }

    function nudge(spec) {
        if (root.active)
            TimersService.add(root.pomo.id, spec);
    }

    // Idle lengths, clamped to 1 min .. 4 h (work) / 2 h (rest).
    function adjust(key, delta) {
        root.cfg[key] = Math.max(60, Math.min(key === "workTime" ? 14400 : 7200, root.cfg[key] + delta));
    }
}
