pragma Singleton
import QtQuick
import qs.modules.theme
import qs.modules.services
import "ActivityModel.js" as Model

// Countdown timers (Pomodoro, and any future timer/stopwatch): remaining
// time with a depleting progress ring; click opens the owner's UI.
//
// Timers live in UI components, so they attach themselves:
//   Component.onCompleted: TimerActivity.attach(root)
//   Component.onDestruction: TimerActivity.detach(root)
// The attached object exposes
//   activityState: { running, alarm, remaining (s), total (s), title, icon }
//   function openActivity()
ActivityProvider {
    id: root

    source: "timers"

    property var owners: []
    // Owner -> first time seen running, for stable ordering
    property var since: ({})

    function attach(owner) {
        if (owner && owners.indexOf(owner) === -1)
            owners = owners.concat([owner]);
    }

    function detach(owner) {
        const i = owners.indexOf(owner);
        if (i !== -1) {
            const next = owners.slice();
            next.splice(i, 1);
            owners = next;
        }
    }

    activities: {
        if (!active)
            return [];
        const out = [];
        for (let i = 0; i < owners.length; i++) {
            const s = owners[i] ? owners[i].activityState : null;
            if (!s || !(s.running || s.alarm))
                continue;
            const total = Math.max(1, s.total || 1);
            out.push({
                id: "timer:" + i,
                category: "task",
                priority: Model.PRIORITY.timer + (s.alarm ? 5 : 0),
                icon: s.alarm ? Icons.alarm : (s.icon || Icons.timer),
                indicator: s.alarm ? "glyph" : "ring",
                label: s.alarm ? I18n.t("activities.pomodoro_done") : Model.formatDuration(s.remaining),
                detail: s.title || "",
                progress: s.alarm ? 0 : Math.max(0, Math.min(1, s.remaining / total)),
                color: s.alarm ? "error" : "primary",
                startedAt: i,
                action: i
            });
        }
        return out;
    }

    function activate(activity, button, screenName) {
        const owner = owners[activity.action];
        if (owner && typeof owner.openActivity === "function")
            owner.openActivity();
    }
}
