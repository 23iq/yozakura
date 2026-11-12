.pragma library

// Saved notification history (notifications.json, read back by
// Notifications.loadNotifications): compact JSON, at most PER_SUMMARY
// entries per app + summary. Unit tested in tests/notification-history.test.cjs.

var PER_SUMMARY = 5;

function toJSON(notif) {
    return {
        "id": notif.id,
        "actions": notif.actions,
        "appIcon": notif.appIcon,
        "appName": notif.appName,
        "desktopEntry": notif.desktopEntry,
        "body": notif.body,
        "image": notif.image,
        "summary": notif.summary,
        "time": notif.time,
        "urgency": notif.urgency,
        "historyPriority": notif.historyPriority,
        "replaceKey": notif.replaceKey,
        "actionData": notif.actionData,
        "cachedAppIcon": notif.cachedAppIcon,
        "cachedImage": notif.cachedImage,
        "isCached": notif.isCached
    };
}

// The newest PER_SUMMARY notifications of each app + summary
function limitPerSummary(notifications) {
    var groups = {};
    notifications.forEach(function (notif) {
        var key = notif.appName + '|' + (notif.summary || '');
        if (!groups[key])
            groups[key] = [];
        groups[key].push(notif);
    });
    var limited = [];
    for (var key in groups) {
        var group = groups[key];
        group.sort(function (a, b) {
            return b.time - a.time;
        });
        limited.push.apply(limited, group.slice(0, PER_SUMMARY));
    }
    return limited;
}

function serialize(list) {
    return JSON.stringify(limitPerSummary(Array.prototype.slice.call(list)).map(toJSON));
}
