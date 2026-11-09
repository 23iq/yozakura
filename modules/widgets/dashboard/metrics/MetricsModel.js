// Pure helpers of the metrics tab (tests/metrics-model.test.cjs).
.pragma library

// The palette colour (Colors.<name>) of a resource series: one per kind,
// the same in its bar and its chart line. GPUs by vendor.
function seriesColor(kind, vendor) {
    if (kind === "cpu")
        return "red";
    if (kind === "ram")
        return "cyan";
    if (kind === "disk")
        return "yellow";
    switch (String(vendor || "").toLowerCase()) {
    case "nvidia":
        return "green";
    case "amd":
        return "red";
    case "intel":
        return "blue";
    default:
        return "magenta";
    }
}

// Icons.<name> of a disk type.
function diskGlyph(type) {
    return type === "ssd" ? "ssd" : (type === "hdd" ? "hdd" : "disk");
}

function capitalize(s) {
    const t = String(s || "");
    return t.charAt(0).toUpperCase() + t.slice(1);
}

// "15.2 GB / 31.0 GB" from KiB.
function memoryText(usedKb, totalKb) {
    const gb = kb => (kb / 1024 / 1024).toFixed(1);
    return `${gb(usedKb || 0)} GB / ${gb(totalKb || 0)} GB`;
}

// The Nerd Font logo of an OS name: exact key, then a partial match, then
// the generic Linux one ("" without logos).
function osLogo(osName, logos) {
    if (!logos)
        return "";
    if (osName && logos[osName])
        return logos[osName];
    if (osName) {
        const lower = osName.toLowerCase();
        for (const distro in logos) {
            if (lower.includes(distro.toLowerCase()))
                return logos[distro];
        }
    }
    return logos["Linux"] || "";
}

// The chart's x layout: `points` samples visible at `zoom` (50 at 1x, at
// least 10), `spacing` px between them, `offset` of the first one so the
// newest sits on the right edge, and the absolute index of the first one.
function chartWindow(width, zoom, historyLength, totalPoints) {
    const maxPoints = Math.max(10, Math.floor(50 / (zoom || 1)));
    const spacing = width / (maxPoints - 1);
    const points = Math.min(maxPoints, historyLength);
    return {
        "maxPoints": maxPoints,
        "spacing": spacing,
        "points": points,
        "offset": width - (points - 1) * spacing,
        "start": totalPoints - points
    };
}

// x of the vertical grid lines (every 10 absolute samples, so they scroll
// with the data) inside a chartWindow().
function gridLines(win, totalPoints) {
    const xs = [];
    for (let i = Math.floor(win.start / 10) * 10; i <= totalPoints + 10; i += 10) {
        const v = i - win.start;
        if (v >= 0 && v < win.points)
            xs.push(win.offset + v * win.spacing);
    }
    return xs;
}

// Interval stepper: 100 ms steps, never under 100 ms.
function stepInterval(ms, delta) {
    return Math.max(100, ms + delta * 100);
}

// A saved chart zoom, kept in 0.2 (everything stored) .. 3 (zoomed in).
function clampZoom(z) {
    return Math.max(0.2, Math.min(3, z || 1));
}
