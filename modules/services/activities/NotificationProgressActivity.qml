pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services
import "NotificationProgress.js" as Progress

// Jobs reported through notifications with the `value` hint (0-100),
// published as transfers (percent units: processed/total = value/100). Updates via replaces_id or the
// synchronous hint reuse the same island; it disappears shortly after 100%,
// when the notification closes, or when the job stops updating.
ActivityProvider {
    id: root

    source: "notificationProgress"

    // Live notification objects with a progress hint. Reading `hints` here
    // makes the binding follow in-place updates.
    readonly property var entries: {
        if (!active || !Notifications.serverNotifications)
            return [];
        const out = [];
        for (const n of Notifications.serverNotifications.values) {
            const e = Progress.parse({
                id: n.id,
                appName: n.appName,
                appIcon: n.appIcon,
                image: n.image,
                summary: n.summary,
                body: n.body,
                hints: n.hints
            });
            if (e)
                out.push(e);
        }
        return out;
    }

    property var jobs: ({})
    property var shown: []

    function refresh() {
        const r = Progress.reduce(jobs, entries, Date.now());
        jobs = r.state;
        shown = r.visible;
    }

    onEntriesChanged: refresh()

    // Only ticks while something can still expire on its own
    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.entries.length > 0 && Progress.needsTick(root.jobs, Date.now())
        onTriggered: root.refresh()
    }

    function iconSource(icon) {
        if (!icon)
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.indexOf("://") !== -1 || icon.startsWith("data:"))
            return icon;
        return Quickshell.iconPath(icon, true);
    }

    // Transfers: de-duplicated against the other download sources (the
    // same Firefox download also shows up as a .part file)
    transfers: shown.map(e => ({
                id: "notificationProgress:" + e.key,
                source: "notificationProgress",
                app: e.appName,
                appIcon: root.iconSource(e.icon),
                title: e.body || e.summary,
                detail: e.body ? e.summary : "",
                processed: e.value,
                total: 100,
                units: "percent",
                rate: -1,
                state: e.value >= 100 ? "done" : "running",
                kind: "download",
                actions: [],
                startedAt: (jobs[e.key] || {}).first || 0,
                ref: e.id
            }))

    // Bring the sender forward (default/open/view action), like clicking
    // the notification itself
    function openTransfer(transfer) {
        Notifications.activateNotification(transfer.ref + Notifications.idOffset);
    }
}
