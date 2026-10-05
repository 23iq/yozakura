.pragma library

// Network throughput from /proc/net/dev for the system widget. Pure;
// tests/desktop-widgets.test.cjs.

// Total received/sent bytes of every interface except loopback.
function totals(text) {
    var rx = 0;
    var tx = 0;
    String(text || "").split("\n").forEach(function (line) {
        var colon = line.indexOf(":");
        if (colon < 0)
            return;
        var name = line.slice(0, colon).trim();
        if (name === "" || name === "lo")
            return;
        var f = line.slice(colon + 1).trim().split(/\s+/);
        if (f.length < 9)
            return;
        rx += Number(f[0]) || 0;
        tx += Number(f[8]) || 0;
    });
    return {
        rx: rx,
        tx: tx
    };
}

// Bytes per second between two samples (null or a counter reset -> 0).
function rate(prev, cur, ms) {
    if (!prev || !cur || !(ms > 0))
        return {
            rx: 0,
            tx: 0
        };
    return {
        rx: Math.max(0, (cur.rx - prev.rx) * 1000 / ms),
        tx: Math.max(0, (cur.tx - prev.tx) * 1000 / ms)
    };
}

function format(bytesPerSec) {
    var units = ["B/s", "KB/s", "MB/s", "GB/s"];
    var v = Math.max(0, bytesPerSec || 0);
    var i = 0;
    while (v >= 1000 && i < units.length - 1) {
        v /= 1024;
        i++;
    }
    return (v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
}

// History values scaled to 0..1 by their own peak (at least `floor`).
function normalized(history, floor) {
    var peak = floor || 1;
    for (var i = 0; i < history.length; i++)
        peak = Math.max(peak, history[i]);
    return history.map(function (v) {
        return v / peak;
    });
}

function push(history, value, max) {
    var next = history.slice();
    next.push(value);
    while (next.length > max)
        next.shift();
    return next;
}
