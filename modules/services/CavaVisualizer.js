.pragma library

// Pure helpers for CavaService. Kept free of QML so they can be unit tested.

var MAX_RANGE = 1000;

// cava config emitting one line of `;`-separated integers (0..MAX_RANGE) per
// frame on stdout. Mono keeps bars ordered low -> high frequency instead of
// cava's mirrored stereo layout.
function buildConfig(bars, framerate) {
    return [
        "[general]",
        "framerate = " + Math.max(1, Math.round(framerate)),
        "bars = " + Math.max(1, Math.round(bars)),
        "autosens = 1",
        "[input]",
        "method = pipewire",
        "source = auto",
        "[output]",
        "method = raw",
        "raw_target = /dev/stdout",
        "data_format = ascii",
        "ascii_max_range = " + MAX_RANGE,
        "bar_delimiter = 59",
        "frame_delimiter = 10",
        "channels = mono",
        "mono_option = average",
        "[smoothing]",
        "noise_reduction = 70",
        ""
    ].join("\n");
}

function silence(count) {
    var out = [];
    for (var i = 0; i < count; i++)
        out.push(0);
    return out;
}

// Parses one raw frame into normalized levels (0..1). Returns null for
// malformed or partial frames so a torn read never flashes empty bars.
function parseFrame(line, expected) {
    if (typeof line !== "string")
        return null;
    var parts = line.trim().split(";");
    if (parts.length && parts[parts.length - 1] === "")
        parts.pop();
    if (parts.length === 0 || (expected > 0 && parts.length !== expected))
        return null;
    var out = new Array(parts.length);
    for (var i = 0; i < parts.length; i++) {
        var v = parseInt(parts[i], 10);
        if (isNaN(v))
            return null;
        out[i] = Math.max(0, Math.min(1, v / MAX_RANGE));
    }
    return out;
}

// Maps `values` onto `count` bars. Groups take their peak so narrow views stay
// lively; wider views interpolate between neighbouring source bars.
function resample(values, count) {
    if (!values || values.length === 0 || count <= 0)
        return silence(Math.max(0, count));
    var n = values.length;
    if (count === n)
        return values.slice();
    var out = new Array(count);
    for (var i = 0; i < count; i++) {
        if (count < n) {
            var start = Math.floor(i * n / count);
            var end = Math.max(start + 1, Math.floor((i + 1) * n / count));
            var peak = 0;
            for (var j = start; j < end; j++)
                peak = Math.max(peak, values[j]);
            out[i] = peak;
        } else {
            var pos = count > 1 ? i * (n - 1) / (count - 1) : 0;
            var lo = Math.floor(pos);
            var hi = Math.min(n - 1, lo + 1);
            var t = pos - lo;
            out[i] = values[lo] * (1 - t) + values[hi] * t;
        }
    }
    return out;
}
