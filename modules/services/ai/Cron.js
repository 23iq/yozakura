.pragma library

// Minimal cron: "m h dom mon dow" with *, lists, ranges, steps and names,
// plus @hourly @daily @weekly @monthly @yearly. Local time.

var MACROS = {
    "@hourly": "0 * * * *",
    "@daily": "0 0 * * *",
    "@midnight": "0 0 * * *",
    "@weekly": "0 0 * * 0",
    "@monthly": "0 0 1 * *",
    "@yearly": "0 0 1 1 *",
    "@annually": "0 0 1 1 *"
};
var MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
var DAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
var RANGES = [[0, 59], [0, 23], [1, 31], [1, 12], [0, 7]];

function _value(token, field) {
    var t = token.toLowerCase();
    if (field === 3 && MONTHS.indexOf(t) >= 0)
        return MONTHS.indexOf(t) + 1;
    if (field === 4 && DAYS.indexOf(t) >= 0)
        return DAYS.indexOf(t);
    if (!/^\d+$/.test(t))
        return NaN;
    return parseInt(t, 10);
}

function _field(spec, field) {
    var min = RANGES[field][0];
    var max = RANGES[field][1];
    var set = {};
    var parts = spec.split(",");
    for (var i = 0; i < parts.length; i++) {
        var part = parts[i];
        var step = 1;
        var slash = part.indexOf("/");
        if (slash >= 0) {
            step = parseInt(part.substring(slash + 1), 10);
            part = part.substring(0, slash);
            if (!(step > 0))
                return null;
        }
        var lo, hi;
        if (part === "*") {
            lo = min;
            hi = max;
        } else if (part.indexOf("-") > 0) {
            var r = part.split("-");
            lo = _value(r[0], field);
            hi = _value(r[1], field);
        } else {
            lo = _value(part, field);
            hi = slash >= 0 ? max : lo;
        }
        if (isNaN(lo) || isNaN(hi) || lo < min || hi > max || lo > hi)
            return null;
        for (var v = lo; v <= hi; v += step)
            set[field === 4 && v === 7 ? 0 : v] = true;
    }
    return set;
}

// Returns {minute, hour, dom, month, dow, domAny, dowAny} or null when invalid.
function parse(expr) {
    var e = String(expr || "").trim();
    if (MACROS[e.toLowerCase()])
        e = MACROS[e.toLowerCase()];
    var f = e.split(/\s+/);
    if (f.length !== 5)
        return null;
    var out = { domAny: f[2] === "*", dowAny: f[4] === "*" };
    var names = ["minute", "hour", "dom", "month", "dow"];
    for (var i = 0; i < 5; i++) {
        var set = _field(f[i], i);
        if (!set)
            return null;
        out[names[i]] = set;
    }
    return out;
}

function valid(expr) {
    return parse(expr) !== null;
}

function matches(expr, date) {
    var c = typeof expr === "string" ? parse(expr) : expr;
    if (!c)
        return false;
    var d = date || new Date();
    if (!c.minute[d.getMinutes()] || !c.hour[d.getHours()] || !c.month[d.getMonth() + 1])
        return false;
    var domOk = !!c.dom[d.getDate()];
    var dowOk = !!c.dow[d.getDay()];
    // Vixie cron: when both day fields are restricted either may match.
    if (!c.domAny && !c.dowAny)
        return domOk || dowOk;
    return domOk && dowOk;
}

// Next matching minute strictly after `from` (null if none within a year).
function next(expr, from) {
    var c = parse(expr);
    if (!c)
        return null;
    var d = new Date((from || new Date()).getTime());
    d.setSeconds(0, 0);
    d.setMinutes(d.getMinutes() + 1);
    for (var i = 0; i < 366 * 24 * 60; i++) {
        if (matches(c, d))
            return d;
        d.setMinutes(d.getMinutes() + 1);
    }
    return null;
}

// Key identifying the minute a schedule fired (prevents double runs).
function minuteKey(date) {
    var d = date || new Date();
    return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate() + "T" + d.getHours() + ":" + d.getMinutes();
}
