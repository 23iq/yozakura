.pragma library

// Pure logic for "progress" notifications: those carrying the standard
// `value` hint (0-100), e.g. `notify-send -h int:value:42`, download
// managers, file copies. Notifications re-sent with
// `x-canonical-private-synchronous` / `synchronous` (or replaces_id) update
// the same activity instead of stacking. Unit tested in
// tests/activities.test.cjs.

var COMPLETE_HOLD_MS = 1500;   // keep a finished job visible this long
var SYNC_STALE_MS = 8000;      // synchronous (OSD-like) updates expire fast
var STALE_MS = 120000;         // a job that stopped updating is gone

// Synchronous tags used by volume/brightness OSD scripts: those are
// momentary indicators, not live activities.
var OSD_TAG = /volume|brightness|backlight|kbd|keyboard|mute|osd|audio|mic/i;

function hint(hints, name) {
    if (!hints || typeof hints !== "object")
        return undefined;
    return hints[name];
}

// 0..100, or null when the notification is not a progress one
function parseValue(hints) {
    var raw = hint(hints, "value");
    if (raw === undefined || raw === null || raw === "" || typeof raw === "boolean")
        return null;
    var n = Number(raw);
    if (!isFinite(n))
        return null;
    return Math.max(0, Math.min(100, n));
}

function syncTag(hints) {
    var tag = hint(hints, "x-canonical-private-synchronous");
    if (tag === undefined || tag === null || tag === "")
        tag = hint(hints, "synchronous");
    if (tag === undefined || tag === null || tag === "" || tag === false)
        return "";
    return String(tag);
}

// notification: { id, appName, appIcon, image, summary, body, hints, desktopEntry }
// Returns a normalised entry, or null when it must not become an activity.
function parse(notification) {
    if (!notification)
        return null;
    var value = parseValue(notification.hints);
    if (value === null)
        return null;
    var tag = syncTag(notification.hints);
    if (tag && OSD_TAG.test(tag))
        return null;
    var app = notification.appName || "";
    return {
        key: tag ? "sync:" + app + ":" + tag : "id:" + notification.id,
        id: notification.id,
        appName: app,
        icon: notification.appIcon || notification.image || "",
        summary: notification.summary || app,
        body: notification.body || "",
        value: value,
        synchronous: tag !== ""
    };
}

// state: { [key]: { first, changed, value, completeAt } }
// entries: parsed entries currently tracked by the notification server.
// Returns { state, visible } where visible keeps entry order.
function reduce(state, entries, now) {
    var prev = state || {};
    var next = {};
    var visible = [];
    // Several live notifications can share a synchronous key (senders that
    // re-send instead of replacing): the newest one carries the progress
    var newest = {};
    for (var n = 0; n < entries.length; n++) {
        var c = entries[n];
        if (c && (!newest[c.key] || Number(c.id) > Number(newest[c.key].id)))
            newest[c.key] = c;
    }
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i] ? newest[entries[i].key] : null;
        if (!e || next[e.key])
            continue;
        var p = prev[e.key];
        var s = {
            first: p ? p.first : now,
            changed: p && p.value === e.value ? p.changed : now,
            value: e.value,
            completeAt: e.value >= 100 ? (p && p.completeAt ? p.completeAt : now) : 0
        };
        next[e.key] = s;
        var staleAfter = e.synchronous ? SYNC_STALE_MS : STALE_MS;
        if (s.completeAt && now - s.completeAt > COMPLETE_HOLD_MS)
            continue;
        if (now - s.changed > staleAfter)
            continue;
        visible.push(e);
    }
    return {
        state: next,
        visible: visible
    };
}

// True while some tracked entry may still change visibility with time alone
function needsTick(state, now) {
    for (var key in state) {
        var s = state[key];
        if (s.completeAt && now - s.completeAt <= COMPLETE_HOLD_MS)
            return true;
        if (now - s.changed <= STALE_MS)
            return true;
    }
    return false;
}
