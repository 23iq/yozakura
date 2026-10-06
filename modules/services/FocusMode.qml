pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import Quickshell
import qs.config
import "timers/FocusSummary.js" as FocusSummary

// Focus mode (system.focus.*): start = Do Not Disturb on (the previous
// state is remembered), a "Focus" timer in the timers service and,
// optionally, no notification badges; end (the timer finished, toggle(),
// the timer cancelled elsewhere) = DND back as it was and a summary of the
// notifications that arrived meanwhile. Survives a shell restart through
// StateService ("focusMode").
Singleton {
    id: root

    readonly property var cfg: Config.system ? Config.system.focus : null
    readonly property int defaultMinutes: root.cfg ? Math.max(1, root.cfg.minutes) : 50

    property bool active: false
    property string timerId: ""
    property real startedAt: 0
    property bool previousDnd: false
    property bool changedDnd: false

    readonly property var timer: root.timerId !== "" ? (TimersService.timers.find(t => t.id === root.timerId) || null) : null
    readonly property real leftMs: root.timer ? root.timer.leftMs : 0
    readonly property bool hideBadges: root.active && (root.cfg ? root.cfg.hideBadges !== false : true)

    // Notifications that are ours (timer and focus notifications)
    readonly property var ownKeys: ["timer-", "focus-"]

    function start(minutes) {
        const m = minutes > 0 ? minutes : root.defaultMinutes;
        if (root.active) {
            // Restart with the new length
            if (root.timerId !== "")
                TimersService.cancel(root.timerId);
            root.timerId = "";
        } else {
            root.startedAt = Date.now();
            root.changedDnd = false;
            if (!root.cfg || root.cfg.dnd !== false) {
                root.previousDnd = !!(Config.notifications && Config.notifications.dnd && Config.notifications.dnd.enabled);
                root.changedDnd = true;
                Notifications.setDnd(true);
            }
        }
        root.active = true;
        TimersService.startSeconds(m * 60, I18n.t("focus.timer_name"), (result, error) => {
            if (result && result.timer)
                root.timerId = result.timer.id;
            else if (error)
                root.stop(false);
            root.persist();
        });
        root.persist();
    }

    // completed: the timer ran out (summary + its ringing stops)
    function stop(completed) {
        if (!root.active)
            return;
        const id = root.timerId;
        root.active = false;
        root.timerId = "";
        if (root.changedDnd)
            Notifications.setDnd(root.previousDnd);
        root.changedDnd = false;
        if (id !== "" && TimersService.timers.some(t => t.id === id))
            TimersService.call(completed ? "dismiss" : "cancel", {
                "id": id
            });
        root.pendingSummary = {
            "id": id,
            "summary": FocusSummary.summarize(Notifications.list.map(n => ({
                        "appName": n.appName,
                        "time": n.time,
                        "replaceKey": n.replaceKey
                    })), root.startedAt, root.ownKeys),
            "minutes": Math.max(1, Math.round((Date.now() - root.startedAt) / 60000))
        };
        if (!root.cfg || root.cfg.summary !== false)
            summaryDelay.restart();
        root.persist();
    }

    function toggle(minutes) {
        if (root.active)
            root.stop(false);
        else
            root.start(minutes);
    }

    // After the backend's own "timer finished" notification, which this
    // one replaces (same replaceKey).
    property var pendingSummary: null
    property Timer summaryDelay: Timer {
        id: summaryDelay
        interval: 700
        onTriggered: {
            const p = root.pendingSummary;
            if (!p)
                return;
            Notifications.notifyInternal({
                "summary": I18n.t("focus.summary.title", p.minutes),
                "body": FocusSummary.body(p.summary, I18n.t),
                "appName": I18n.t("focus.title"),
                "appIcon": "",
                "urgency": "normal",
                "replaceKey": p.id ? "timer-" + p.id : "focus-summary",
                "hints": {
                    "suppress-sound": true
                }
            });
            root.pendingSummary = null;
        }
    }

    function persist() {
        if (!StateService.initialized)
            return;
        StateService.set("focusMode", {
            "active": root.active,
            "timerId": root.timerId,
            "startedAt": root.startedAt,
            "previousDnd": root.previousDnd,
            "changedDnd": root.changedDnd
        });
    }

    function restore() {
        const s = StateService.get("focusMode", null);
        if (!s || !s.active || root.active)
            return;
        root.timerId = s.timerId || "";
        root.startedAt = Number(s.startedAt) || Date.now();
        root.previousDnd = !!s.previousDnd;
        root.changedDnd = !!s.changedDnd;
        root.active = true;
        // The timer may have finished while the shell was down
        Qt.callLater(() => {
            if (root.active && TimersService.ready && !TimersService.timers.some(t => t.id === root.timerId))
                root.stop(true);
        });
    }

    property Connections stateWatch: Connections {
        target: StateService
        function onInitializedChanged() {
            if (StateService.initialized)
                root.restore();
        }
    }

    property Connections timersWatch: Connections {
        target: TimersService
        function onFired(ev) {
            if (root.active && ev && ev.done && ev.id === root.timerId)
                root.stop(true);
        }
        // The focus timer went away (cancelled from the panel, CLI...)
        function onTimersChanged() {
            // Looked up here: the `timer` binding may not have caught up yet
            if (root.active && TimersService.ready && root.timerId !== "" && !TimersService.timers.some(t => t.id === root.timerId))
                root.stop(false);
        }
    }

    Component.onCompleted: {
        if (StateService.initialized)
            root.restore();
    }
}
