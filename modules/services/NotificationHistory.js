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

// Ids at or below INTERNAL_MAX are the shell's own notifications
// (Notifications.notifyInternal: -1000000 - counter).
var INTERNAL_MAX = -1000000;

// The saved history merged under the live notifications (the history is
// read once, possibly after notifications arrived). Live ones are never
// replaced: `saved` entries that are a live notification saved and read
// back (same id, time and summary) are skipped, and saved entries keep
// their id unless it could reach a live or future notification:
// - a server notification's list id is its server id + idOffset, so while
//   live server notifications exist (`fixedOffset`) the offset must not
//   move and every positive saved id moves to an unused id in
//   (INTERNAL_MAX, 0); without them the offset moves above the saved ids,
//   as it always did;
// - a saved internal id taken by a live one gets a new internal id.
// live: [{id, time, summary}]. Returns {entries: [{json, id}], idOffset,
// internalIdCounter} (the counter past every internal id).
function merge(saved, live, idOffset, internalIdCounter, fixedOffset) {
    var liveById = {};
    var used = {};
    live.forEach(function (l) {
        liveById[l.id] = l;
        used[l.id] = true;
    });
    var entries = (Array.isArray(saved) ? saved : []).filter(function (j) {
        if (j === null || typeof j !== "object")
            return false;
        var l = liveById[j.id];
        return !(l && l.time === j.time && l.summary === j.summary);
    });
    var counter = internalIdCounter;
    entries.concat(live).forEach(function (x) {
        if (typeof x.id === "number" && x.id <= INTERNAL_MAX)
            counter = Math.max(counter, -x.id + INTERNAL_MAX + 1);
    });
    // Pass 1: the ids that stay; pass 2: new ids for the others.
    var keep = entries.map(function (j) {
        var id = j.id;
        var ok = typeof id === "number" && id === Math.floor(id) && !used[id] && !(fixedOffset && id > 0);
        if (ok)
            used[id] = true;
        return ok;
    });
    var nextLocal = -1;
    var out = entries.map(function (j, i) {
        var id = j.id;
        if (!keep[i]) {
            if (typeof id === "number" && id <= INTERNAL_MAX) {
                id = INTERNAL_MAX - counter++;
            } else {
                while (used[nextLocal])
                    nextLocal--;
                id = nextLocal--;
            }
            used[id] = true;
        }
        return {
            "json": j,
            "id": id
        };
    });
    var offset = idOffset;
    if (!fixedOffset) {
        var maxId = 0;
        out.forEach(function (e) {
            if (e.id > maxId)
                maxId = e.id;
        });
        offset = maxId + 1;
    }
    return {
        "entries": out,
        "idOffset": offset,
        "internalIdCounter": counter
    };
}
