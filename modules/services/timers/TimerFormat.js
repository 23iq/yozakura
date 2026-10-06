.pragma library

// Pure helpers behind TimersService and the timer views: time left /
// elapsed from the backend view (timers.state, see
// docs/superpowers/plans/2026-10-06-F1-timers-backend.md), display rows,
// duration and clock formatting, and the live preview of a quick input
// Intent. `tr(key, ...args)` translates (I18n.t). Tested in
// tests/timers-format.test.cjs.

function num(v) {
    var n = Number(v);
    return isNaN(n) ? 0 : n;
}

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

// Milliseconds left of a timer at `now` (local ms + skew): running timers
// count down to endsAt, paused/ringing ones keep the view's leftMs.
function timerLeft(t, now) {
    if (!t)
        return 0;
    if (t.state === "running" && t.endsAt)
        return Math.max(0, num(t.endsAt) - now);
    return t.state === "ringing" ? 0 : Math.max(0, num(t.leftMs));
}

// Stopwatch elapsed ms at `now`.
function stopwatchElapsed(sw, now) {
    if (!sw)
        return 0;
    if (sw.state === "running" && sw.startedAt)
        return Math.max(0, num(sw.accumMs) + now - num(sw.startedAt));
    return Math.max(0, num(sw.elapsedMs) || num(sw.accumMs));
}

// "1:05:09", "25:00" (h:mm:ss / mm:ss). Rounds up, so a timer shows 0:00
// only when it is done.
function clock(ms, roundUp) {
    var total = roundUp === false ? Math.floor(Math.max(0, ms) / 1000) : Math.ceil(Math.max(0, ms) / 1000);
    var h = Math.floor(total / 3600);
    var m = Math.floor((total % 3600) / 60);
    var s = total % 60;
    return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : pad(m) + ":" + pad(s);
}

// Compact length without seconds for the notch ("25m", "1h 5m", "45s").
function compact(ms) {
    var total = Math.ceil(Math.max(0, ms) / 1000);
    if (total < 60)
        return total + "s";
    var minutes = Math.ceil(total / 60);
    var h = Math.floor(minutes / 60);
    var m = minutes % 60;
    if (h === 0)
        return m + "m";
    return m === 0 ? h + "h" : h + "h " + m + "m";
}

// Notch label of a countdown: clock() with seconds, compact() without.
function label(ms, showSeconds) {
    return showSeconds ? clock(ms) : compact(ms);
}

// Human length of a number of seconds ("10m", "1h 30m", "1m 30s").
function duration(seconds) {
    var total = Math.round(Math.max(0, num(seconds)));
    var h = Math.floor(total / 3600);
    var m = Math.floor((total % 3600) / 60);
    var s = total % 60;
    var parts = [];
    if (h)
        parts.push(h + "h");
    if (m)
        parts.push(m + "m");
    if (s || parts.length === 0)
        parts.push(s + "s");
    return parts.join(" ");
}

// Wall-clock time of a unix ms value ("18:05" / "6:05 PM").
function timeOfDay(ms, use12h) {
    var d = new Date(num(ms));
    var h = d.getHours();
    var m = pad(d.getMinutes());
    if (!use12h)
        return pad(h) + ":" + m;
    var suffix = h >= 12 ? "PM" : "AM";
    return ((h + 11) % 12 + 1) + ":" + m + " " + suffix;
}

// Title of a timer: its name, else the Pomodoro phase, else "Timer".
function timerTitle(t, tr) {
    if (t && t.pomodoro) {
        var phase = tr("timers.phase." + (t.pomodoro.phase || "work"));
        return t.name ? t.name + " · " + phase : phase;
    }
    return t && t.name ? t.name : tr("timers.timer");
}

var STATE_ORDER = {
    "ringing": 0,
    "running": 1,
    "paused": 2
};

// Timers in display order (ringing, running, paused; then by creation)
// with their time left and progress at `now`.
function timerRows(view, now) {
    var list = view && view.timers ? Array.prototype.slice.call(view.timers) : [];
    return list.map(function (t) {
        var left = timerLeft(t, now);
        var total = Math.max(1, num(t.totalMs));
        return {
            "kind": "timer",
            "id": t.id,
            "name": t.name || "",
            "state": t.state,
            "ringing": t.state === "ringing",
            "running": t.state === "running",
            "leftMs": left,
            "totalMs": num(t.totalMs),
            "progress": t.state === "ringing" ? 0 : Math.max(0, Math.min(1, left / total)),
            "pomodoro": t.pomodoro || null,
            "createdAt": num(t.createdAt),
            "timer": t
        };
    }).sort(function (a, b) {
        var d = (STATE_ORDER[a.state] === undefined ? 3 : STATE_ORDER[a.state]) - (STATE_ORDER[b.state] === undefined ? 3 : STATE_ORDER[b.state]);
        return d !== 0 ? d : a.createdAt - b.createdAt;
    });
}

// Reminders due within `leadMs` (all when leadMs <= 0), soonest first.
function reminderRows(view, now, leadMs) {
    var list = view && view.reminders ? Array.prototype.slice.call(view.reminders) : [];
    return list.map(function (r) {
        return {
            "kind": "reminder",
            "id": r.id,
            "message": r.message || "",
            "at": num(r.at),
            "leftMs": Math.max(0, num(r.at) - now)
        };
    }).filter(function (r) {
        return !(leadMs > 0) || r.leftMs <= leadMs;
    }).sort(function (a, b) {
        return a.at - b.at;
    });
}

// Stopwatch laps newest first.
function laps(sw) {
    var list = sw && sw.laps ? Array.prototype.slice.call(sw.laps) : [];
    return list.slice().reverse();
}

function stopwatchActive(sw) {
    return !!sw && (sw.state === "running" || sw.state === "paused");
}

// Live preview of a quick input Intent (timers.parse):
// {icon: "timer"|"alarm"|"watch"|"countdown", text}.
function preview(intent, tr, use12h) {
    if (!intent || !intent.kind)
        return null;
    var name = intent.name || "";
    switch (intent.kind) {
    case "timer":
        return {
            "icon": "timer",
            "text": tr("timers.preview.timer", duration(intent.seconds)) + (name ? " · " + name : "")
        };
    case "reminder":
        return {
            "icon": "alarm",
            "text": tr("timers.preview.reminder", timeOfDay(intent.at, use12h)) + (name ? " · " + name : "")
        };
    case "stopwatch":
        return {
            "icon": "watch",
            "text": tr("timers.preview.stopwatch")
        };
    case "pomodoro":
        return {
            "icon": "countdown",
            "text": tr("timers.preview.pomodoro")
        };
    }
    return null;
}
