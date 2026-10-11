.pragma library

// Pure helpers of the dashboard "stage" home (tests/dashboard-stage-model.test.cjs).

// Translation key of the idle hero's greeting for an hour (0..23).
function greetingKey(hour) {
    var h = Number(hour) || 0;
    if (h >= 5 && h < 12)
        return "dashboard.stage.greeting.morning";
    if (h >= 12 && h < 18)
        return "dashboard.stage.greeting.afternoon";
    if (h >= 18 && h < 23)
        return "dashboard.stage.greeting.evening";
    return "dashboard.stage.greeting.night";
}

// Milliseconds until something -> {key, n} for "now" / "in 40 min" /
// "in 3 h"; a day or more away (or already past) -> {key: "", n: 0}.
function relativeIn(ms) {
    var v = Number(ms);
    if (!isFinite(v) || v < -60000)
        return { key: "", n: 0 };
    var min = Math.round(v / 60000);
    if (min < 1)
        return { key: "dashboard.stage.now", n: 0 };
    if (min < 60)
        return { key: "dashboard.stage.in_min", n: min };
    var h = Math.round(min / 60);
    if (h < 24)
        return { key: "dashboard.stage.in_hours", n: h };
    return { key: "", n: 0 };
}

// A khal start date ("2026-10-11", "11.10.2026" or "10/11/2026") and an
// optional "14:30" -> epoch ms (local time); unknown -> NaN. All-day
// events start at midnight.
function eventAt(date, time) {
    var d = String(date || "").trim();
    var y, mo, day, m;
    if ((m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(d))) {
        y = +m[1]; mo = +m[2]; day = +m[3];
    } else if ((m = /^(\d{1,2})\.(\d{1,2})\.(\d{2,4})$/.exec(d))) {
        day = +m[1]; mo = +m[2]; y = +m[3];
    } else if ((m = /^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$/.exec(d))) {
        mo = +m[1]; day = +m[2]; y = +m[3];
    } else {
        return NaN;
    }
    if (y < 100)
        y += 2000;
    var hh = 0, mm = 0;
    var t = /^(\d{1,2})[:.](\d{2})/.exec(String(time || "").trim());
    if (t) {
        hh = +t[1]; mm = +t[2];
    }
    return new Date(y, mo - 1, day, hh, mm).getTime();
}

function sameDay(a, b) {
    var x = new Date(a), y = new Date(b);
    return x.getFullYear() === y.getFullYear() && x.getMonth() === y.getMonth() && x.getDate() === y.getDate();
}

// Rows of the NEXT block, soonest first, at most `limit`: calendar events
// ({date, time, title} from CalendarEvents) that have not ended, plus the
// running timers and reminders (TimersService rows; the Pomodoro first, it
// is what the user is doing). Row: {kind, title, time, at, leftMs, today,
// allDay}; `time` is the event's own text (empty for all-day / timers).
function nextRows(src, limit) {
    var s = src || {};
    var now = Number(s.now) || Date.now();
    var out = [];
    var events = s.events ? Array.prototype.slice.call(s.events) : [];
    events.forEach(function (e) {
        if (!e || !e.title)
            return;
        var at = eventAt(e.date, e.time);
        if (!isFinite(at))
            return;
        var allDay = !e.time;
        if (allDay ? !sameDay(at, now) && at < now : at < now - 15 * 60000)
            return;
        out.push({ kind: "event", title: String(e.title), time: e.time || "", at: at,
            leftMs: Math.max(0, at - now), today: sameDay(at, now), allDay: allDay });
    });
    var timers = s.timers ? Array.prototype.slice.call(s.timers) : [];
    timers.forEach(function (t) {
        if (!t)
            return;
        var left = Math.max(0, Number(t.leftMs) || 0);
        out.push({ kind: t.pomodoro ? "pomodoro" : "timer", title: t.name || "", time: "", at: now + left,
            leftMs: left, today: true, allDay: false });
    });
    var reminders = s.reminders ? Array.prototype.slice.call(s.reminders) : [];
    reminders.forEach(function (r) {
        if (!r)
            return;
        var left = Math.max(0, Number(r.leftMs) || 0);
        out.push({ kind: "reminder", title: r.message || "", time: "", at: Number(r.at) || now + left,
            leftMs: left, today: sameDay(Number(r.at) || now + left, now), allDay: false });
    });
    out.sort(function (a, b) {
        if ((a.kind === "pomodoro") !== (b.kind === "pomodoro"))
            return a.kind === "pomodoro" ? -1 : 1;
        return a.at - b.at;
    });
    var n = Number(limit) || 0;
    return n > 0 ? out.slice(0, n) : out;
}

// Milliseconds -> "m:ss" (a running timer's remaining time).
function clock(ms) {
    var s = Math.max(0, Math.round((Number(ms) || 0) / 1000));
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (sec < 10 ? "0" : "") + sec;
}

// The week that holds `now`, starting on `firstDay` (0 = Sunday):
// seven {day, weekday, today, past, iso}.
function weekDays(now, firstDay) {
    var t = now instanceof Date ? now : new Date(Number(now) || Date.now());
    var lead = (t.getDay() - (Number(firstDay) || 0) + 7) % 7;
    var out = [];
    for (var i = 0; i < 7; i++) {
        var d = new Date(t.getFullYear(), t.getMonth(), t.getDate() - lead + i);
        out.push({ day: d.getDate(), weekday: d.getDay(), today: i === lead, past: i < lead,
            iso: d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate() });
    }
    return out;
}

// Days of the week strip that hold an event: {iso: true} (iso as weekDays).
function eventDays(events) {
    var out = {};
    (events ? Array.prototype.slice.call(events) : []).forEach(function (e) {
        var at = e ? eventAt(e.date, e.time) : NaN;
        if (isFinite(at)) {
            var d = new Date(at);
            out[d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate()] = true;
        }
    });
    return out;
}

// RGBA bytes of a small sample of the art -> its tone {r, g, b} (0..1):
// the average weighted towards saturated, mid-bright pixels, so a cover's
// colour wins over its black or white background; null when transparent.
function averageTone(data) {
    var r = 0, g = 0, b = 0, w = 0;
    var n = data ? data.length : 0;
    for (var i = 0; i + 3 < n; i += 4) {
        var a = data[i + 3] / 255;
        if (a < 0.5)
            continue;
        var R = data[i] / 255, G = data[i + 1] / 255, B = data[i + 2] / 255;
        var max = Math.max(R, G, B), min = Math.min(R, G, B);
        var sat = max > 0 ? (max - min) / max : 0;
        var mid = 1 - Math.abs((max + min) - 1);
        var weight = a * (0.15 + sat * mid);
        r += R * weight; g += G * weight; b += B * weight; w += weight;
    }
    if (w <= 0)
        return null;
    return { r: r / w, g: g / w, b: b / w };
}

function channel(c) {
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

// WCAG relative luminance of {r, g, b} (0..1).
function luminance(c) {
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

function contrast(a, b) {
    var la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

function mix(base, top, alpha) {
    return { r: base.r + (top.r - base.r) * alpha, g: base.g + (top.g - base.g) * alpha, b: base.b + (top.b - base.b) * alpha };
}

// Strength of the hero's tint: the largest alpha (up to maxAlpha) at which
// `tone` laid over `base` keeps `ink` (the hero's text colour) at
// `minContrast` or more; 0 without a tone. Bright art over a dark theme
// (or dark art over a light one) is thus toned down instead of washing
// out the title.
function tintAlpha(tone, base, ink, maxAlpha, minContrast) {
    if (!tone || !base || !ink)
        return 0;
    var want = Number(minContrast) || 4.5;
    var a = Math.max(0, Number(maxAlpha) || 0);
    while (a > 0.001 && contrast(mix(base, tone, a), ink) < want)
        a -= 0.02;
    return Math.max(0, Math.round(a * 100) / 100);
}

// The art's tone made into a flood colour for the hero card: its hue with
// the saturation lifted (at least `minSat`) and the lightness moved to
// `light` (a deep tone over a dark theme, a pale one over a light theme),
// so the card can take it at full strength and the ink stays readable.
// {r, g, b} -> {r, g, b}; null in, null out.
function floodTone(tone, light, minSat) {
    if (!tone)
        return null;
    var r = tone.r, g = tone.g, b = tone.b;
    var max = Math.max(r, g, b), min = Math.min(r, g, b);
    var h = 0, s = 0, l = (max + min) / 2;
    var d = max - min;
    if (d > 1e-6) {
        s = d / (1 - Math.abs(2 * l - 1));
        if (max === r)
            h = ((g - b) / d) % 6;
        else if (max === g)
            h = (b - r) / d + 2;
        else
            h = (r - g) / d + 4;
        h = (h * 60 + 360) % 360;
    }
    s = d > 1e-6 ? Math.min(0.9, Math.max(Number(minSat) || 0, s * 1.2)) : 0;
    l = Math.max(0, Math.min(1, Number(light)));
    var c = (1 - Math.abs(2 * l - 1)) * s;
    var x = c * (1 - Math.abs((h / 60) % 2 - 1));
    var m = l - c / 2;
    var rgb = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return { r: rgb[0] + m, g: rgb[1] + m, b: rgb[2] + m };
}

// Network rate (bytes/s) -> "820 B/s", "12 KB/s", "1.4 MB/s".
function rate(bytes) {
    var v = Math.max(0, Number(bytes) || 0);
    if (v < 1024)
        return Math.round(v) + " B/s";
    if (v < 1024 * 1024)
        return Math.round(v / 1024) + " KB/s";
    var mb = v / (1024 * 1024);
    return (mb < 10 ? mb.toFixed(1) : Math.round(mb)) + " MB/s";
}
