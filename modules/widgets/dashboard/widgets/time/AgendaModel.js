.pragma library

// Rows of the agenda widget. Calendar events win when a source provides
// them ({id, title, at}); there is no calendar source yet, so the widget
// passes none and lists the reminders and timers of TimersService
// (TimerFormat rows) instead, soonest first. The Pomodoro has its own widget.
function rows(src, limit) {
    var s = src || {};
    var now = Number(s.now) || 0;
    var out = [];
    if (s.events && s.events.length > 0) {
        out = Array.prototype.map.call(s.events, function (e) {
            var at = Number(e.at) || 0;
            return { "kind": "event", "id": e.id || e.title, "title": e.title || "", "at": at, "leftMs": Math.max(0, at - now) };
        });
    } else {
        var reminders = s.reminders ? Array.prototype.slice.call(s.reminders) : [];
        var timers = s.timers ? Array.prototype.slice.call(s.timers) : [];
        reminders.forEach(function (r) {
            out.push({ "kind": "reminder", "id": r.id, "title": r.message || "", "at": Number(r.at) || 0, "leftMs": Number(r.leftMs) || 0 });
        });
        timers.forEach(function (t) {
            if (t.pomodoro)
                return;
            var left = Number(t.leftMs) || 0;
            out.push({ "kind": "timer", "id": t.id, "title": t.name || "", "at": now + left, "leftMs": left,
                "ringing": !!t.ringing, "paused": t.state === "paused" });
        });
    }
    out.sort(function (a, b) { return a.leftMs - b.leftMs; });
    return limit > 0 ? out.slice(0, limit) : out;
}
