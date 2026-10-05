.pragma library

// Pure helpers for SystemStats.qml (tested in tests/panel-modules.test.cjs).

var ITEMS = ["cpu", "ram", "gpu", "cpuTemp", "gpuTemp", "net"];

// Byte rate as a short label: 512 B/s -> "512B", 2.5 MiB/s -> "2.5M".
function rate(bps) {
    var v = Math.max(0, bps || 0);
    var units = ["B", "K", "M", "G"];
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024;
        i++;
    }
    return (v >= 10 || i === 0 ? Math.round(v) : Math.round(v * 10) / 10) + units[i];
}

function percent(v) {
    return Math.round(Math.max(0, Math.min(100, v || 0))) + "%";
}

function temp(v) {
    return v === undefined || v === null || v < 0 ? "--°" : Math.round(v) + "°";
}

// Items from moduleOptions, known ids only, in the given order.
function itemsOf(raw) {
    var out = [];
    if (!raw || typeof raw.length !== "number")
        return ["cpu", "ram"];
    for (var i = 0; i < raw.length; i++) {
        if (ITEMS.indexOf(raw[i]) !== -1 && out.indexOf(raw[i]) === -1)
            out.push(raw[i]);
    }
    return out;
}

// Severity 0..2 for colouring (usage % or temperature °C)
function level(kind, value) {
    if (kind === "cpuTemp" || kind === "gpuTemp")
        return value >= 85 ? 2 : (value >= 70 ? 1 : 0);
    if (kind === "net")
        return 0;
    return value >= 90 ? 2 : (value >= 70 ? 1 : 0);
}
