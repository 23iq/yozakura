pragma Singleton
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import "ActivityModel.js" as Model
import "../timers/TimerFormat.js" as TimerFormat

// Timers of the backend (TimersService): running timers and Pomodoro with
// a depleting ring (system.timers.notchStyle "ring") or plain time
// ("text"), ringing ones as a pulsing alarm until dismissed, the running
// stopwatch and reminders due within system.timers.reminderLead minutes.
// Click: a ringing timer stops, anything else opens the timers hub.
ActivityProvider {
    id: root

    source: "timers"

    readonly property var cfg: Config.system ? Config.system.timers : null
    readonly property bool ringStyle: (root.cfg ? root.cfg.notchStyle : "ring") !== "text"
    readonly property bool showSeconds: root.cfg ? root.cfg.showSeconds !== false : true
    readonly property bool pulse: root.cfg ? root.cfg.pulseOnFinish !== false : true
    readonly property bool showStopwatch: root.cfg ? root.cfg.showStopwatch !== false : true
    readonly property real reminderLeadMs: (root.cfg ? root.cfg.reminderLead : 15) * 60000

    function timerActivity(t) {
        const total = Math.max(1, t.totalMs);
        return {
            "id": "timer:" + t.id,
            "category": "task",
            "priority": Model.PRIORITY.timer + (t.ringing ? 5 : 0),
            "icon": t.ringing ? Icons.alarm : (t.pomodoro ? Icons.countdown : Icons.timer),
            "indicator": t.ringing ? (root.pulse ? "dot" : "glyph") : (root.ringStyle ? "ring" : "glyph"),
            "label": t.ringing ? I18n.t("activities.pomodoro_done") : TimerFormat.label(t.leftMs, root.showSeconds),
            "detail": TimerFormat.timerTitle(t, I18n.t),
            "progress": t.ringing || !root.ringStyle ? -1 : Math.max(0, Math.min(1, t.leftMs / total)),
            "color": t.ringing ? "error" : "primary",
            "startedAt": t.createdAt,
            "action": {
                "kind": "timer",
                "id": t.id,
                "ringing": t.ringing
            }
        };
    }

    activities: {
        if (!root.active)
            return [];
        const out = TimersService.timers.filter(t => t.state !== "paused").map(t => root.timerActivity(t));
        if (root.showStopwatch && TimersService.stopwatch.state === "running")
            out.push({
                "id": "stopwatch",
                "category": "task",
                "priority": Model.PRIORITY.timer - 1,
                "icon": Icons.watch,
                "indicator": "glyph",
                "label": TimerFormat.label(TimersService.stopwatchMs, root.showSeconds),
                "detail": I18n.t("timers.stopwatch"),
                "progress": -1,
                "color": "primary",
                "startedAt": Number(TimersService.stopwatch.startedAt) || 0,
                "action": {
                    "kind": "stopwatch"
                }
            });
        if (root.reminderLeadMs > 0)
            TimerFormat.reminderRows(TimersService.view, TimersService.now, root.reminderLeadMs).forEach(r => out.push({
                    "id": "reminder:" + r.id,
                    "category": "task",
                    "priority": Model.PRIORITY.timer - 2,
                    "icon": Icons.alarm,
                    "indicator": "glyph",
                    "label": TimerFormat.label(r.leftMs, root.showSeconds),
                    "detail": r.message || I18n.t("timers.reminder"),
                    "progress": -1,
                    "color": "secondary",
                    "startedAt": r.at,
                    "action": {
                        "kind": "reminder",
                        "id": r.id
                    }
                }));
        return out;
    }

    function activate(activity, button, screenName) {
        const a = activity && activity.action ? activity.action : {};
        if (a.kind === "timer" && a.ringing && button !== Qt.RightButton) {
            TimersService.dismiss(a.id);
            return;
        }
        TimersService.openHub("timer", screenName);
    }
}
