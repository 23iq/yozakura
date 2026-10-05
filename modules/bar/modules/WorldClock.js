.pragma library

// Pure helpers for WorldClocks.qml (tested in tests/panel-modules.test.cjs).

// "+0930" / "-0500" -> minutes east of UTC; null when malformed.
function parseOffset(text) {
    var m = /^\s*([+-])(\d{2}):?(\d{2})\s*$/.exec(String(text || ""));
    if (!m)
        return null;
    var minutes = parseInt(m[2], 10) * 60 + parseInt(m[3], 10);
    return m[1] === "-" ? -minutes : minutes;
}

// Wall time at `offsetMinutes` for the instant `nowMs` (epoch ms).
// Returns {hours, minutes, dayDelta} where dayDelta is the calendar day
// difference against the local day of `localOffsetMinutes`.
function timeAt(nowMs, offsetMinutes, localOffsetMinutes) {
    var shifted = new Date(nowMs + offsetMinutes * 60000);
    var local = new Date(nowMs + localOffsetMinutes * 60000);
    var dayMs = 86400000;
    var dayDelta = Math.floor(shifted.getTime() / dayMs) - Math.floor(local.getTime() / dayMs);
    return {
        "hours": shifted.getUTCHours(),
        "minutes": shifted.getUTCMinutes(),
        "dayDelta": dayDelta
    };
}

function pad(n) {
    return n < 10 ? "0" + n : String(n);
}

function format(t, use12h) {
    if (!use12h)
        return pad(t.hours) + ":" + pad(t.minutes);
    var h = t.hours % 12;
    return (h === 0 ? 12 : h) + ":" + pad(t.minutes) + (t.hours < 12 ? " AM" : " PM");
}

// Zones from moduleOptions: [{label, zone}] with valid strings only.
function zonesOf(raw) {
    var list = [];
    if (!raw || typeof raw.length !== "number")
        return list;
    for (var i = 0; i < raw.length; i++) {
        var z = raw[i];
        if (z && typeof z.zone === "string" && z.zone.length > 0 && /^[A-Za-z0-9_+\-\/]+$/.test(z.zone))
            list.push({
                "label": typeof z.label === "string" && z.label.length > 0 ? z.label : z.zone.split("/").pop().replace(/_/g, " "),
                "zone": z.zone
            });
    }
    return list;
}
