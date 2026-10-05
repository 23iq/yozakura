.pragma library

// Pure notification policy (no QML types; node-tested in
// tests/notification-policy.test.cjs). Config shape: config/defaults/notifications.js.
// Used by modules/services/Notifications.qml (what pops up, for how long,
// with or without sound), the notch and CornerToasts.qml (where).

var PRESENTATIONS = ["auto", "notch", "corner"];
var POSITIONS = ["auto", "top-left", "top", "top-right", "bottom-left", "bottom", "bottom-right"];
var RULE_ACTIONS = ["mute", "priority", "alwaysShow", "soundOff"];

// "auto" presentation by the style of the primary panel (the bar the notch
// pairs with; modules/bar/panels/PanelStyles.js): island-like chrome grows
// toasts from the notch, taskbar/menubar/terminal-like chrome uses corner
// toasts. Styles not listed (classic, a future one, no panel at all) follow
// the edge rule: notch when it sits on the bar's edge.
var STYLE_PRESENTATION = {
    "islands": "notch",
    "corners": "notch",
    "menubar": "corner",
    "statusline": "corner",
    "ribbon": "corner",
    "rail": "corner",
    "dock": "corner"
};

function oneOf(value, list, fallback) {
    return list.indexOf(value) !== -1 ? value : fallback;
}

// ctx: {barStyle, barPosition, notchPosition}
function resolvePresentation(presentation, ctx) {
    var p = oneOf(presentation, PRESENTATIONS, "auto");
    if (p !== "auto")
        return p;
    var c = ctx || {};
    var byStyle = STYLE_PRESENTATION[c.barStyle];
    if (byStyle)
        return byStyle;
    var bar = c.barPosition || "top";
    var notch = c.notchPosition || "top";
    return bar === notch ? "notch" : "corner";
}

// Corner of the corner toasts; "auto" sits on the bar's side (a bottom
// taskbar gets bottom-right toasts, everything else top-right).
function resolvePosition(position, ctx) {
    var p = oneOf(position, POSITIONS, "auto");
    if (p !== "auto")
        return p;
    return (ctx && ctx.barPosition === "bottom") ? "bottom-right" : "top-right";
}

// {vertical: "top"|"bottom", horizontal: "left"|"right"|"center"}
function anchorsOf(position) {
    var parts = String(position || "top-right").split("-");
    return {
        "vertical": parts[0] === "bottom" ? "bottom" : "top",
        "horizontal": parts.length > 1 ? (parts[1] === "left" ? "left" : "right") : "center"
    };
}

function showsOnScreen(screens, name) {
    if (!screens || screens.length === 0)
        return true;
    for (var i = 0; i < screens.length; i++) {
        if (screens[i] === name)
            return true;
    }
    return false;
}

function norm(value) {
    return String(value || "").replace(/\.desktop$/i, "").trim().toLowerCase();
}

function globToRegExp(glob) {
    var esc = glob.replace(/[.+^${}()|[\]\\?]/g, "\\$&").replace(/\*/g, ".*");
    return new RegExp("^" + esc + "$", "i");
}

// Does one rule's app pattern match the notification (app name or desktop
// entry, case-insensitive; `*` is a wildcard)?
function ruleMatches(pattern, notif) {
    var p = String(pattern || "").trim();
    if (!p || !notif)
        return false;
    var names = [norm(notif.appName), norm(notif.desktopEntry)].filter(function (n) {
        return n !== "";
    });
    if (p.indexOf("*") !== -1) {
        var re = globToRegExp(p.toLowerCase());
        return names.some(function (n) {
            return re.test(n);
        });
    }
    var want = norm(p);
    return names.indexOf(want) !== -1;
}

// Every matching rule adds its action: {mute, priority, alwaysShow, soundOff}.
function matchRules(rules, notif) {
    var flags = {
        "mute": false,
        "priority": false,
        "alwaysShow": false,
        "soundOff": false
    };
    var list = rules || [];
    for (var i = 0; i < list.length; i++) {
        var r = list[i];
        if (!r || RULE_ACTIONS.indexOf(r.action) === -1)
            continue;
        if (ruleMatches(r.app, notif))
            flags[r.action] = true;
    }
    return flags;
}

// "HH:MM" -> minutes since midnight, or -1 when malformed.
function parseTime(text) {
    var m = /^(\d{1,2}):(\d{2})$/.exec(String(text || "").trim());
    if (!m)
        return -1;
    var h = parseInt(m[1], 10), min = parseInt(m[2], 10);
    if (h > 23 || min > 59)
        return -1;
    return h * 60 + min;
}

function hasDay(days, day) {
    if (!days)
        return false;
    for (var i = 0; i < days.length; i++) {
        if (Number(days[i]) === day)
            return true;
    }
    return false;
}

// Is `date` inside the DND schedule? `days` lists the days (0 = Sunday) a
// window *starts* on; a window past midnight (22:00-07:00) ends the next day.
// from == to means the whole day.
function inSchedule(schedule, date) {
    if (!schedule || !schedule.enabled)
        return false;
    var from = parseTime(schedule.from), to = parseTime(schedule.to);
    if (from < 0 || to < 0)
        return false;
    var day = date.getDay();
    var now = date.getHours() * 60 + date.getMinutes();
    if (from === to)
        return hasDay(schedule.days, day);
    if (from < to)
        return hasDay(schedule.days, day) && now >= from && now < to;
    if (now >= from)
        return hasDay(schedule.days, day);
    return now < to && hasDay(schedule.days, (day + 6) % 7);
}

function dndActive(cfg, date) {
    var dnd = (cfg && cfg.dnd) || {};
    return !!dnd.enabled || inSchedule(dnd.schedule, date);
}

function isCritical(urgency) {
    var u = String(urgency === undefined || urgency === null ? "" : urgency).toLowerCase();
    return u === "2" || u === "critical";
}

// What happens to a new notification.
//   notif: {appName, desktopEntry, urgency, expireTimeout}
//   dnd:   Do Not Disturb in effect (manual or scheduled, see Notifications.silent)
// -> {popup, sound, priority, timeout (ms, 0 = until dismissed)}
function decide(cfg, notif, dnd) {
    var c = cfg || {};
    var flags = matchRules(c.rules, notif);
    var critical = isCritical(notif && notif.urgency);
    var allowCritical = !c.dnd || c.dnd.allowCritical !== false;
    var bypass = flags.alwaysShow || flags.priority || (critical && allowCritical);
    var popup = !flags.mute && (!dnd || bypass);
    var sound = popup && !!(c.sound && c.sound.enabled) && !flags.soundOff;
    var timeout;
    var expire = notif ? Number(notif.expireTimeout) : -1;
    if (flags.priority)
        timeout = 0;
    else if (isNaN(expire) || expire < 0)
        timeout = Math.max(0, Number(c.timeout) || 0);
    else
        timeout = expire;
    return {
        "popup": popup,
        "sound": sound,
        "priority": flags.priority,
        "timeout": timeout
    };
}

// Group key of a notification in popups and history.
function groupKey(notif, groupByApp) {
    var app = (notif && notif.appName) || "";
    return groupByApp === false ? app + "#" + (notif ? notif.id : "") : app;
}

// Ids of popups to hide so at most `max` stay visible (oldest first; a
// priority popup outlives normal ones).
function overflowPopups(popups, max) {
    var limit = Math.max(1, Number(max) || 1);
    var list = (popups || []).slice();
    if (list.length <= limit)
        return [];
    list.sort(function (a, b) {
        var pa = a.historyPriority > 0 ? 1 : 0, pb = b.historyPriority > 0 ? 1 : 0;
        if (pa !== pb)
            return pa - pb;
        return a.time - b.time;
    });
    return list.slice(0, list.length - limit).map(function (n) {
        return n.id;
    });
}

// Ids of history entries to drop so at most `size` remain (oldest first,
// visible popups are never dropped).
function trimHistory(list, size) {
    var keep = Math.max(0, Number(size) || 0);
    var items = list || [];
    if (items.length <= keep)
        return [];
    var candidates = items.filter(function (n) {
        return !n.popup;
    }).sort(function (a, b) {
        return a.time - b.time;
    });
    var excess = items.length - keep;
    return candidates.slice(0, excess).map(function (n) {
        return n.id;
    });
}
