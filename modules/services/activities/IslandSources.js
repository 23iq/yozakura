.pragma library

// Pure logic of the island's own activity sources (battery, bluetooth,
// osd, extras): when they fire and the activity/transfer they publish.
// Ephemeral activities keep one id per source, so a new event updates the
// visible item in place instead of replacing it (no flicker, no resize
// jump). Unit tested in tests/island-sources.test.cjs.

var LOW_BATTERY = 20; // same threshold as Battery.qml's alert

function _pct(v) {
    var n = Number(v);
    if (!isFinite(n))
        n = 0;
    return Math.max(0, Math.min(100, Math.round(n)));
}

function _level(v) {
    var n = Number(v);
    if (!isFinite(n))
        return 0;
    return Math.max(0, Math.min(1, n));
}

// prev/cur: { available, percent, charging }. Returns null or
// { kind: "charging" | "low", percent }.
function batteryEvent(prev, cur, low) {
    if (!prev || !cur || !prev.available || !cur.available)
        return null;
    var limit = low > 0 ? low : LOW_BATTERY;
    if (cur.charging && !prev.charging)
        return { kind: "charging", percent: cur.percent };
    if (!cur.charging && cur.percent <= limit && !(prev.percent <= limit && !prev.charging))
        return { kind: "low", percent: cur.percent };
    return null;
}

function batteryActivity(evt, labels) {
    var l = labels || {};
    var low = evt.kind === "low";
    return {
        id: "battery",
        source: "battery",
        category: "privacy",
        priority: 60, // ActivityModel.PRIORITY.battery
        indicator: "ring",
        icon: low ? "batteryLow" : "batteryCharging",
        label: _pct(evt.percent) + "%",
        detail: (low ? l.low : l.charging) || "",
        progress: _pct(evt.percent) / 100,
        color: low ? "error" : "primary"
    };
}

// Connected devices before/after ({address, name, battery}; battery -1 =
// unknown) -> [{kind, name, battery, address}], connects first.
function bluetoothEvents(prev, cur) {
    var p = prev || [];
    var c = cur || [];
    function has(list, addr) {
        for (var i = 0; i < list.length; i++)
            if (list[i].address === addr)
                return true;
        return false;
    }
    var out = [];
    var i;
    for (i = 0; i < c.length; i++)
        if (!has(p, c[i].address))
            out.push({ kind: "connected", name: c[i].name, battery: c[i].battery, address: c[i].address });
    for (i = 0; i < p.length; i++)
        if (!has(c, p[i].address))
            out.push({ kind: "disconnected", name: p[i].name, battery: p[i].battery, address: p[i].address });
    return out;
}

function bluetoothActivity(evt, labels) {
    var l = labels || {};
    var known = Number(evt.battery) >= 0;
    var state = (evt.kind === "connected" ? l.connected : l.disconnected) || "";
    return {
        id: "bluetooth",
        source: "bluetooth",
        category: "privacy",
        priority: 55, // ActivityModel.PRIORITY.bluetooth
        indicator: known ? "ring" : "glyph",
        icon: evt.kind === "connected" ? "bluetoothConnected" : "bluetoothX",
        label: known ? _pct(evt.battery) + "%" : String(evt.name || ""),
        detail: state ? String(evt.name || "") + " · " + state : String(evt.name || ""),
        progress: known ? _pct(evt.battery) / 100 : -1,
        color: evt.kind === "connected" ? "primary" : "overSurfaceVariant"
    };
}

// OsdService.toIsland(kind, value, muted, device): kind "volume" | "mic" |
// "brightness" | "device"; value 0..1.
function osdActivity(kind, value, muted, device, labels) {
    var l = labels || {};
    var icons = { volume: "speakerHigh", mic: "mic", brightness: "sun", device: "speakerHigh" };
    var lvl = _level(value);
    return {
        id: "osd",
        source: "osd",
        category: "privacy",
        priority: 85, // ActivityModel.PRIORITY.osd
        indicator: "ring",
        icon: muted ? (kind === "mic" ? "micSlash" : "speakerX") : (icons[kind] || "speakerHigh"),
        label: muted ? (l.muted || "") : Math.round(lvl * 100) + "%",
        detail: device ? String(device) : "",
        progress: muted ? 0 : lvl,
        color: muted ? "error" : "primary"
    };
}

// ExtrasService.jobs ({key: {job, kind, entries, state, percent, phase}})
// -> running/queued transfers (TransferModel.js shape, percent units).
// nameOf(entryId) gives the display name.
function extrasTransfers(jobs, nameOf, now) {
    var out = [];
    for (var k in jobs || {}) {
        var j = jobs[k];
        if (!j || (j.state !== "running" && j.state !== "queued"))
            continue;
        var names = (j.entries || []).map(function (e) {
            return nameOf ? nameOf(e) : e;
        });
        out.push({
            id: "extras:" + (j.job || k),
            source: "extras",
            app: "",
            title: names.join(" · "),
            kind: "update",
            units: "percent",
            processed: _pct(j.percent),
            total: 100,
            rate: -1,
            state: j.state,
            detail: j.phase || "",
            actions: [],
            startedAt: now || 0
        });
    }
    return out;
}
