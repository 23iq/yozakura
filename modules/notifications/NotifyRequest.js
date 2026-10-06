.pragma library

// A backend notify.request (CLI `notify send`, svc/timers...) as the
// options of Notifications.notifyInternal(). Actions may carry:
//   clipboard  value copied with wl-copy when clicked (colorpicker formats)
//   call       {method, params}: a backend IPC call made when clicked
//              (timers "+5 min" -> timers.add, "Stop" -> timers.dismiss)
// Timer notifications (replaceKey "timer-...") get their button texts
// translated by identifier and no notification sound: the timer alarm
// (TimersService) plays its own. `deps`: {call(method, params),
// copy(value), tr(key)}. Tested in tests/notify-request.test.cjs.

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
    var handlers = {};
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
            handlers[a.identifier] = copyHandler(deps, a.clipboard);
        else if (a.call && a.call.method)
            handlers[a.identifier] = callHandler(deps, String(a.call.method), a.call.params || {});
    }
    var opts = {
        "summary": (data && data.summary) || "",
        "body": (data && data.body) || "",
        "appName": (data && data.appName) || "Yozakura",
        "appIcon": (data && data.appIcon) || "",
        "image": (data && data.image) || "",
        "urgency": (data && data.urgency) || "normal",
        "expireTimeout": (data && data.expireTimeout) || 5000,
        "replaceKey": (data && data.replaceKey) || "",
        "actions": actions,
        "actionHandlers": handlers,
        "popup": true
    };
    if (timer)
        opts.hints = {
            "suppress-sound": true
        };
    return opts;
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
