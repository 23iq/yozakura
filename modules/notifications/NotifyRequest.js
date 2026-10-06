.pragma library

// A backend notify.request (CLI `notify send`, svc/timers...) as the
// options of Notifications.notifyInternal(). Actions may carry:
//   clipboard  value copied with wl-copy when clicked (colorpicker formats)
//   call       {method, params}: a backend IPC call made when clicked
//              (timers "+5 min" -> timers.add, "Stop" -> timers.dismiss)
// Timer notifications (replaceKey "timer-...") get their button texts
// translated by identifier and no notification sound: the timer alarm
// (TimersService) plays its own. `deps`: {call(method, params),
// copy(value), tr(key)}. What an action does is kept as data
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
        if (timer && TIMER_TEXTS[a.identifier] && deps.tr)
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
    var opts = {
        "summary": (data && data.summary) || "",
        "body": (data && data.body) || "",
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
