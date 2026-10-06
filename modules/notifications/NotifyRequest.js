.pragma library

// A backend notify.request (CLI `notify send`, svc/timers...) as the
// options of Notifications.notifyInternal(). Actions may carry:
//   clipboard  value copied with wl-copy when clicked (colorpicker formats)
//   call       {method, params}: a backend IPC call made when clicked
//              (timers "+5 min" -> timers.add, "Stop" -> timers.dismiss)
// Localized backend texts: summaryKey / bodyKey are translation keys
// shown instead of summary / body (the English fallback) when the
// language files know them; `args` fill their %1, %2... (an arg may be a
// {key, args, text} itself, translated the same way); an action's
// labelKey translates its text. Timer notifications (replaceKey
// "timer-...") without labelKey get their button texts translated by
// identifier, and no notification sound: the timer alarm (TimersService)
// plays its own. `deps`: {call(method, params), copy(value), tr(key),
// has(key) (optional: a translation exists)}. What an action does is kept as data
// (`actionData`, saved with the notification) and turned into handlers by
// handlers(), so the buttons still work on a notification restored from
// history. expireTimeout 0 (the backend's "until dismissed") keeps a
// notification with actions on screen (a waiting task, a timer alarm).
// Tested in tests/notify-request.test.cjs.

var TIMER_TEXTS = {
    "snooze": "timers.action.snooze",
    "stop": "timers.action.stop",
    "dismiss": "timers.action.stop"
};

function isTimer(data) {
    return String((data && data.replaceKey) || "").indexOf("timer-") === 0;
}

function build(data, deps) {
    var timer = isTimer(data);
    var raw = (data && data.actions) || [];
    var actions = [];
    var actionData = {};
    for (var i = 0; i < raw.length; i++) {
        var a = raw[i];
        if (!a || !a.identifier)
            continue;
        var text = a.text || a.identifier;
        if (a.labelKey)
            text = localized(a.labelKey, [], text, deps);
        else if (timer && TIMER_TEXTS[a.identifier] && deps.tr)
            text = deps.tr(TIMER_TEXTS[a.identifier]);
        actions.push({
            "identifier": a.identifier,
            "text": text
        });
        if (a.clipboard !== undefined && a.clipboard !== null)
            actionData[a.identifier] = {
                "clipboard": String(a.clipboard)
            };
        else if (a.call && a.call.method)
            actionData[a.identifier] = {
                "call": {
                    "method": String(a.call.method),
                    "params": a.call.params || {}
                }
            };
    }
    var args = (data && Array.isArray(data.args)) ? data.args : [];
    var opts = {
        "summary": localized(data && data.summaryKey, args, (data && data.summary) || "", deps),
        "body": localized(data && data.bodyKey, args, (data && data.body) || "", deps),
        "appName": (data && data.appName) || "Yozakura",
        "appIcon": (data && data.appIcon) || "",
        "image": (data && data.image) || "",
        "urgency": (data && data.urgency) || "normal",
        "expireTimeout": expireTimeout(data, actions.length > 0),
        "replaceKey": (data && data.replaceKey) || "",
        "actions": actions,
        "actionData": actionData,
        "actionHandlers": handlers(actionData, deps),
        "popup": true
    };
    if (timer)
        opts.hints = {
            "suppress-sound": true
        };
    return opts;
}

// The translation of key with %1, %2... replaced by args (one pass, so an
// argument's own "%2" stays as is), or fallback when there is no key or
// no translation for it.
function localized(key, args, fallback, deps) {
    if (!key || !deps || !deps.tr || (deps.has && !deps.has(key)))
        return fallback;
    var list = args || [];
    return String(deps.tr(key)).replace(/%(\d+)/g, function (m, n) {
        var i = Number(n) - 1;
        return i >= 0 && i < list.length ? argText(list[i], deps) : m;
    });
}

function argText(a, deps) {
    if (a === null || a === undefined)
        return "";
    if (typeof a === "object" && a.key)
        return localized(String(a.key), Array.isArray(a.args) ? a.args : [], a.text !== undefined && a.text !== null ? String(a.text) : "", deps);
    return String(a);
}

// Popup lifetime in ms: 0 = until dismissed (only with actions: the
// backend sends 0 when it sets nothing), -1 = the user's default.
function expireTimeout(data, hasActions) {
    var raw = data ? data.expireTimeout : undefined;
    var t = Number(raw);
    if (raw === undefined || raw === null || raw === "" || isNaN(t))
        return 5000;
    if (t < 0)
        return -1;
    if (t === 0)
        return hasActions ? 0 : 5000;
    return t;
}

// The quiet notice shown when an action's backend call fails (a request
// already answered, a task that is gone).
function failureNotice(err, tr) {
    return {
        "summary": tr ? tr("notifications.action_failed") : "notifications.action_failed",
        "body": String((err && err.message) || err || ""),
        "appIcon": "dialog-warning",
        "urgency": "low",
        "expireTimeout": 4000,
        "hints": {
            "suppress-sound": true
        }
    };
}

// Handlers ({identifier: function}) for saved action data.
function handlers(actionData, deps) {
    var out = {};
    var d = actionData && typeof actionData === "object" ? actionData : {};
    for (var id in d) {
        var a = d[id];
        if (!a)
            continue;
        if (a.clipboard !== undefined && a.clipboard !== null)
            out[id] = copyHandler(deps, a.clipboard);
        else if (a.call && a.call.method)
            out[id] = callHandler(deps, String(a.call.method), a.call.params || {});
    }
    return out;
}

// Closures in their own scope (one per action, not the loop variable).
function copyHandler(deps, value) {
    return function () {
        deps.copy(String(value));
    };
}

function callHandler(deps, method, params) {
    return function () {
        deps.call(method, params);
    };
}
