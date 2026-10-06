pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services.timers
import "timers/TimerFormat.js" as TimerFormat

// Thin client of the backend timers service (backend/pkg/svc/timers; API
// in docs/superpowers/plans/2026-10-06-F1-timers-backend.md): many named
// timers, Pomodoro, one stopwatch with laps, reminders. The backend owns
// the state and fires on time; this keeps its last view (timers.state),
// ticks locally once a second while something runs, rings the alarm on
// timers.event and holds the notch hub state (quick input + list).
Singleton {
    id: root

    readonly property var cfg: Config.system ? Config.system.timers : null

    // Last backend view and its clock skew (backend now - local now)
    property var view: ({
            "timers": [],
            "reminders": [],
            "stopwatch": {
                "state": "idle"
            },
            "ringing": 0,
            "active": false
        })
    property real skew: 0
    property bool ready: false
    // Local time + skew; refreshed by the tick below
    property real now: Date.now()

    readonly property var timers: TimerFormat.timerRows(root.view, root.now)
    readonly property var reminders: TimerFormat.reminderRows(root.view, root.now, 0)
    readonly property var stopwatch: root.view && root.view.stopwatch ? root.view.stopwatch : ({
            "state": "idle"
        })
    readonly property real stopwatchMs: TimerFormat.stopwatchElapsed(root.stopwatch, root.now)
    readonly property bool stopwatchActive: TimerFormat.stopwatchActive(root.stopwatch)
    readonly property var ringingTimers: root.timers.filter(t => t.ringing)
    readonly property int ringing: root.ringingTimers.length
    readonly property var pomodoro: root.timers.find(t => !!t.pomodoro) || null
    readonly property bool hasAnything: root.timers.length > 0 || root.reminders.length > 0 || root.stopwatchActive
    readonly property bool use12h: Config.bar ? !!Config.bar.use12hFormat : false

    // Every timers.event (kind, id, name, message, phase, done, missed)
    signal fired(var event)
    // A call failed (short English message from the backend)
    signal failed(string message)
    property string lastError: ""

    // ── notch hub: quick input (+ list), one screen at a time ──
    property bool hubOpen: false
    property string hubScreen: ""
    // "timer" (quick timer input) | "note" (quick note capture)
    property string hubMode: "timer"
    // Screen the alarm panel shows on (focused screen when it fired)
    property string alarmScreen: ""

    function openHub(mode, screenName) {
        root.hubMode = mode || "timer";
        root.hubScreen = screenName || GlobalStates.focusedScreenName();
        root.hubOpen = true;
    }
    function closeHub() {
        root.hubOpen = false;
    }
    function toggleHub(mode, screenName) {
        if (root.hubOpen && root.hubMode === (mode || "timer"))
            root.closeHub();
        else
            root.openHub(mode, screenName);
    }

    // ── backend calls ──
    function call(method, params, callback) {
        BackendService.call("timers." + method, params || {}, (result, error) => {
            if (error) {
                root.lastError = error.message || String(error);
                root.failed(root.lastError);
            } else {
                root.lastError = "";
            }
            if (callback)
                callback(result, error);
        });
    }

    // Live preview of a quick input line: callback(intent | null, error)
    function parse(text, callback) {
        BackendService.call("timers.parse", {
            "text": text
        }, (result, error) => callback(error ? null : result, error ? (error.message || String(error)) : ""));
    }
    function quick(text, callback) {
        root.call("quick", {
            "text": text
        }, callback);
    }
    function start(spec, name, callback) {
        root.call("start", {
            "spec": spec,
            "name": name || ""
        }, callback);
    }
    function startSeconds(seconds, name, callback) {
        root.call("start", {
            "seconds": seconds,
            "name": name || ""
        }, callback);
    }
    function startPomodoro(workSeconds, breakSeconds) {
        const p = {};
        if (workSeconds > 0)
            p.work = workSeconds;
        if (breakSeconds > 0)
            p.break = breakSeconds;
        root.call("pomodoro", p);
    }
    function pause(id) {
        root.call("pause", {
            "id": id
        });
    }
    function resume(id) {
        root.call("resume", {
            "id": id
        });
    }
    function toggle(id) {
        const t = root.timers.find(x => x.id === id);
        if (t && t.state === "running")
            root.pause(id);
        else if (t && t.state === "paused")
            root.resume(id);
    }
    // spec: "+1m", "-1m", "5m" (on a ringing timer: snooze)
    function add(id, spec) {
        root.call("add", {
            "id": id,
            "spec": spec
        });
    }
    function reset(id) {
        root.call("reset", {
            "id": id
        });
    }
    function cancel(id) {
        root.call("cancel", {
            "id": id
        });
    }
    // id "" dismisses every ringing timer
    function dismiss(id) {
        root.call("dismiss", id ? {
            "id": id
        } : {});
    }
    function stopwatchAction(action) {
        root.call("stopwatch", {
            "action": action
        });
    }
    function reminderAdd(when, message, callback) {
        root.call("reminderAdd", {
            "when": when,
            "message": message || ""
        }, callback);
    }
    function reminderCancel(id) {
        root.call("reminderCancel", {
            "id": id
        });
    }

    // ── state ──
    function applyState(data) {
        if (!data || typeof data !== "object")
            return;
        root.skew = (Number(data.now) || Date.now()) - Date.now();
        root.view = data;
        root.ready = true;
        root.now = Date.now() + root.skew;
        if (root.ringing === 0 && alarm.ringing)
            alarm.stop();
    }

    function applyEvent(ev) {
        if (!ev || typeof ev !== "object")
            return;
        if (ev.done) {
            root.alarmScreen = GlobalStates.focusedScreenName();
            // Reminders do not stay ringing: one round of the tone is enough
            if (ev.kind === "reminder")
                alarm.play(alarm.tone);
            else
                alarm.start();
        } else if (ev.kind === "pomodoro" && ev.phase) {
            alarm.cue();
            // system.pomodoro.autoStart off: wait at each phase change
            if (Config.system && Config.system.pomodoro && !Config.system.pomodoro.autoStart)
                root.pause(ev.id);
        }
        root.fired(ev);
    }

    property AlarmPlayer alarm: AlarmPlayer {
        id: alarm
    }

    // One tick a second while something counts (timers, stopwatch,
    // reminders); nothing runs when idle.
    property Timer tick: Timer {
        interval: 1000
        repeat: true
        running: root.ready && (!!root.view.active || root.reminders.length > 0 || root.stopwatchActive)
        triggeredOnStart: true
        onTriggered: root.now = Date.now() + root.skew
    }

    Component.onCompleted: {
        BackendService.addSubscription(["timers"], (service, data) => {
            if (service === "timers.state")
                root.applyState(data);
            else if (service === "timers.event")
                root.applyEvent(data);
        });
    }
}
