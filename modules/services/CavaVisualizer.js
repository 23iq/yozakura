.pragma library

// Pure helpers for CavaService. Kept free of QML so they can be unit tested.

var MAX_RANGE = 1000;

// performance.visualizerFps: frames per second cava delivers. Every frame
// redraws the panel window hosting a visualizer, so the rate is kept in a
// range where the bars still look smooth (they ease between frames) and the
// cost stays bounded. Missing or broken values use the default.
var DEFAULT_RATE = 30;
var MIN_RATE = 15;
var MAX_RATE = 60;

function clampRate(value) {
    var n = Number(value);
    if (value === null || value === undefined || value === "" || !isFinite(n) || n <= 0)
        return DEFAULT_RATE;
    return Math.max(MIN_RATE, Math.min(MAX_RATE, Math.round(n)));
}

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
    var out = [];
    return parseInto(line, expected, out) > 0 ? out : null;
}

// Frame reader for the hot path (one call per cava frame): parses `line`
// without temporary strings and returns `current` itself when the frame
// equals it (silence, a held note), a new array when it differs, or null
// for a malformed frame. Only a changed frame allocates.
function readFrame(line, expected, current) {
    if (typeof line !== "string")
        return null;
    var n = parseInto(line, expected, _scratch);
    if (n <= 0)
        return null;
    if (current && current.length === n) {
        var same = true;
        for (var i = 0; i < n && same; i++)
            same = current[i] === _scratch[i];
        if (same)
            return current;
    }
    return _scratchCopy(n);
}

// Reused by readFrame: frames are parsed synchronously, one at a time.
var _scratch = [];

function _scratchCopy(n) {
    var out = new Array(n);
    for (var i = 0; i < n; i++)
        out[i] = _scratch[i];
    return out;
}

// Parses `;`-separated integers (optional trailing `;`, surrounding
// whitespace) into `out` as 0..1 levels. Returns the bar count, or 0 when
// the line is malformed or does not hold `expected` bars (when > 0).
function parseInto(line, expected, out) {
    var len = line.length;
    var i = 0;
    var count = 0;
    while (i < len && line.charCodeAt(i) <= 32)
        i++;
    while (len > i && line.charCodeAt(len - 1) <= 32)
        len--;
    if (i >= len)
        return 0;
    while (i < len) {
        var neg = false;
        var c = line.charCodeAt(i);
        if (c === 45 || c === 43) { // - +
            neg = c === 45;
            i++;
        }
        var v = 0;
        var digits = 0;
        while (i < len) {
            c = line.charCodeAt(i);
            if (c < 48 || c > 57)
                break;
            v = v * 10 + (c - 48);
            digits++;
            i++;
        }
        if (digits === 0)
            return 0;
        if (i < len) {
            if (c !== 59) // ;
                return 0;
            i++;
        }
        if (expected > 0 && count >= expected)
            return 0;
        out[count++] = neg ? 0 : Math.min(1, v / MAX_RANGE);
    }
    if (expected > 0 && count !== expected)
        return 0;
    out.length = count;
    return count;
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
