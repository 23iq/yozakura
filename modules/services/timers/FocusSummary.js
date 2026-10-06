.pragma library

// Focus mode summary: notifications that arrived while focusing, counted
// per app. `notifs` are plain {appName, time, replaceKey}; keys starting
// with one of `ownKeys` (timer/focus notifications) are not counted.
// Tested in tests/timers-quick-input.test.cjs.

function summarize(notifs, since, ownKeys) {
    var own = ownKeys || [];
    var counts = {};
    var count = 0;
    var list = notifs ? Array.prototype.slice.call(notifs) : [];
    list.forEach(function (n) {
        if (!n || Number(n.time) < since)
            return;
        var key = String(n.replaceKey || "");
        if (own.some(function (k) {
            return key.indexOf(k) === 0;
        }))
            return;
        var app = String(n.appName || "").trim() || "?";
        counts[app] = (counts[app] || 0) + 1;
        count++;
    });
    var apps = Object.keys(counts).map(function (name) {
        return {
            "name": name,
            "count": counts[name]
        };
    }).sort(function (a, b) {
        return b.count - a.count || (a.name < b.name ? -1 : 1);
    });
    return {
        "count": count,
        "apps": apps
    };
}

// Body of the end-of-focus notification: "3 notifications: Telegram (2),
// Mail" / "No notifications".
function body(summary, tr, maxApps) {
    if (!summary || summary.count === 0)
        return tr("focus.summary.none");
    var limit = maxApps || 4;
    var names = summary.apps.slice(0, limit).map(function (a) {
        return a.count > 1 ? a.name + " (" + a.count + ")" : a.name;
    });
    if (summary.apps.length > limit)
        names.push("…");
    return tr("focus.summary.some", summary.count, names.join(", "));
}
