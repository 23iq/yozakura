.pragma library

// Pure model of the idle timeline (editors/IdleTimeline.qml): the idle
// listeners (system.idle.listeners: [{timeout, onTimeout, onResume}]) read
// as four steps - dim the screen, lock, turn the screen off, sleep - each at
// a time or never. Listeners that are none of these are kept as they are.
// Node-tested (tests/settings-power.test.cjs).

// The steps in timeline order, how a listener's command is recognised, and
// the listener a step gets when it is turned on again.
var STEPS = [
    {
        "id": "dim",
        "match": /brightness/,
        "listener": {
            "onTimeout": "yozakura brightness 10 -s",
            "onResume": "yozakura brightness -r"
        }
    },
    {
        "id": "lock",
        "match": /lock/,
        "listener": {
            "onTimeout": "loginctl lock-session"
        }
    },
    {
        "id": "off",
        "match": /screen off|dpms off|dpms,? ?off/,
        "listener": {
            "onTimeout": "yozakura screen off",
            "onResume": "yozakura screen on"
        }
    },
    {
        "id": "sleep",
        "match": /suspend|hibernate|sleep/,
        "listener": {
            "onTimeout": "yozakura suspend"
        }
    }
];

// Times a handle snaps to (seconds), from 15 s to 2 h.
var NICE = [15, 30, 45, 60, 90, 120, 150, 180, 240, 300, 420, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200];
var MIN = NICE[0];
var MAX = NICE[NICE.length - 1];
// The share of the track that is time; the rest (at the end) is "never".
var TIME_SPAN = 0.86;

// The step a listener belongs to ("" for none).
function stepOf(listener) {
    var cmd = String((listener && listener.onTimeout) || "");
    for (var i = 0; i < STEPS.length; i++) {
        if (STEPS[i].match.test(cmd))
            return STEPS[i].id;
    }
    return "";
}

// {dim, lock, off, sleep}: the first listener's timeout of each step, or
// null (never).
function read(listeners) {
    var out = {
        "dim": null,
        "lock": null,
        "off": null,
        "sleep": null
    };
    (listeners || []).forEach(function (l) {
        var id = stepOf(l);
        var t = Number(l.timeout);
        if (id && out[id] === null && isFinite(t))
            out[id] = t;
    });
    return out;
}

function copy(v) {
    return JSON.parse(JSON.stringify(v));
}

// `listeners` with step `id` at `seconds` (null: never - its listeners are
// removed). A step turned on again gets its default listener. Sorted by
// time; other listeners keep their place in that order.
function withStep(listeners, id, seconds) {
    var list = copy(listeners || []);
    var out = [];
    var done = false;
    list.forEach(function (l) {
        if (stepOf(l) !== id)
            out.push(l);
        else if (seconds !== null && !done) {
            l.timeout = seconds;
            out.push(l);
            done = true;
        }
    });
    if (seconds !== null && !done) {
        var def = null;
        STEPS.forEach(function (s) {
            if (s.id === id)
                def = copy(s.listener);
        });
        if (def) {
            def.timeout = seconds;
            out.push(def);
        }
    }
    return out.sort(function (a, b) {
        return Number(a.timeout) - Number(b.timeout);
    });
}

// Track position (0..1, TIME_SPAN = MAX) <-> seconds, on a log scale.
function toPos(seconds) {
    if (seconds === null || seconds === undefined)
        return 1;
    var t = Math.max(MIN, Math.min(MAX, Number(seconds)));
    return TIME_SPAN * Math.log(t / MIN) / Math.log(MAX / MIN);
}

// The snapped time at a track position, or null past the time span.
function fromPos(pos) {
    if (pos > TIME_SPAN + (1 - TIME_SPAN) / 3)
        return null;
    var p = Math.max(0, Math.min(TIME_SPAN, pos));
    var t = MIN * Math.pow(MAX / MIN, p / TIME_SPAN);
    var best = NICE[0];
    NICE.forEach(function (n) {
        if (Math.abs(Math.log(n / t)) < Math.abs(Math.log(best / t)))
            best = n;
    });
    return best;
}

// The range a step's handle may move in: after the earlier steps that are
// on, before the later ones (the timeline keeps dim -> lock -> off ->
// sleep). {min, max} in seconds (max null: may go to never).
function range(steps, id) {
    var ids = STEPS.map(function (s) {
        return s.id;
    });
    var i = ids.indexOf(id);
    var lo = MIN, hi = null;
    for (var a = i - 1; a >= 0; a--) {
        if (steps[ids[a]] !== null) {
            lo = steps[ids[a]];
            break;
        }
    }
    for (var b = i + 1; b < ids.length; b++) {
        if (steps[ids[b]] !== null) {
            hi = steps[ids[b]];
            break;
        }
    }
    return {
        "min": lo,
        "max": hi
    };
}

// A dragged time kept inside its range (null = never: only when no later
// step is on).
function clampTo(steps, id, seconds) {
    var r = range(steps, id);
    if (seconds === null)
        return r.max === null ? null : r.max;
    var t = Math.max(r.min, seconds);
    return r.max === null ? t : Math.min(r.max, t);
}

// Pixel centres `xs` (in timeline order) pushed apart to at least `gap`
// and kept inside [lo, hi]: handles at nearly the same time stay apart.
function spread(xs, gap, lo, hi) {
    var out = xs.slice();
    for (var i = 1; i < out.length; i++)
        out[i] = Math.max(out[i], out[i - 1] + gap);
    if (out.length > 0)
        out[out.length - 1] = Math.min(out[out.length - 1], hi);
    for (var j = out.length - 2; j >= 0; j--)
        out[j] = Math.min(out[j], out[j + 1] - gap);
    if (out.length > 0 && out[0] < lo) {
        out[0] = lo;
        for (var k = 1; k < out.length; k++)
            out[k] = Math.max(out[k], out[k - 1] + gap);
    }
    return out;
}

// "45 s", "5 min", "5 min 30 s", "1 h 30 min".
function label(seconds, tr) {
    if (seconds === null)
        return tr("prefs.power.never");
    if (seconds < 60)
        return tr("prefs.power.seconds").replace("%1", seconds);
    if (seconds < 600 && seconds % 60 !== 0)
        return tr("prefs.power.minutes_seconds").replace("%1", Math.floor(seconds / 60)).replace("%2", seconds % 60);
    var m = Math.round(seconds / 60);
    if (m < 60)
        return tr("prefs.power.minutes").replace("%1", m);
    var h = Math.floor(m / 60), rest = m % 60;
    return rest === 0 ? tr("prefs.power.hours").replace("%1", h) : tr("prefs.power.hours_minutes").replace("%1", h).replace("%2", rest);
}
