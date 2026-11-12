.pragma library

// Pure scheduling helpers for IdleService: instead of a 1 s tick for the
// whole time the user is away, the service sleeps until the next idle
// threshold anyone cares about. Tested in tests/idle-schedule.test.cjs.

// Longest single wait; a later threshold is reached in several steps.
var MAX_STEP_MS = 86400000;

// Whole idle seconds after which a listener fires. Mirrors the old 1 s
// tick (`elapsed >= (timeout || 60)` checked at 1, 2, 3... s): a fractional
// timeout fires at the next whole second, zero/negative ones at 1 s, and a
// non-numeric one never.
function listenerSeconds(listener) {
    var raw = listener ? listener.timeout : undefined;
    var t = Number(raw || 60);
    if (isNaN(t))
        return Infinity;
    return Math.max(1, Math.ceil(t));
}

// Sorted, de-duplicated whole-second thresholds: every listener's timeout
// plus `extra` delays (values <= 0 or not finite are ignored there).
function thresholds(listeners, extra) {
    var out = [];
    var n = listeners ? listeners.length : 0;
    for (var i = 0; i < n; i++)
        out.push(listenerSeconds(listeners[i]));
    var e = extra || [];
    for (var j = 0; j < e.length; j++) {
        var d = Number(e[j]);
        if (d > 0)
            out.push(Math.max(1, Math.ceil(d)));
    }
    out = out.filter(function (v) {
        return isFinite(v);
    }).sort(function (a, b) {
        return a - b;
    });
    return out.filter(function (v, k) {
        return k === 0 || v !== out[k - 1];
    });
}

// Milliseconds from `elapsedMs` of idle time to the next threshold, capped
// at MAX_STEP_MS; -1 when every threshold has been reached.
function nextDelay(sortedThresholds, elapsedMs) {
    var list = sortedThresholds || [];
    for (var i = 0; i < list.length; i++) {
        var at = list[i] * 1000;
        if (at > elapsedMs)
            return Math.min(MAX_STEP_MS, at - elapsedMs);
    }
    return -1;
}

// How far past its armed interval a wait may measure before the gap can
// only be a suspend (the timer does not run while suspended, the wall clock
// does): timer latency stays well under it.
var SUSPEND_SLACK_MS = 2000;

// Idle time to credit for the current wait when the thresholds change in
// its middle. `spentMs`: wall-clock time since the wait was armed, minus
// any suspend the service was told about; `armedMs`: the interval the
// timer was armed for, or -1 when no wait is armed. Never more than the
// armed interval, and nothing when the gap exceeds it by more than
// SUSPEND_SLACK_MS: a suspend the service missed, whose share of the gap
// is unknown, so the wait restarts rather than fire a listener early.
function waitCredit(spentMs, armedMs) {
    var spent = Math.max(0, Number(spentMs) || 0);
    if (!(armedMs >= 0))
        return spent;
    if (spent > armedMs + SUSPEND_SLACK_MS)
        return 0;
    return Math.min(spent, armedMs);
}

// Indices of listeners due at `elapsedSec` that have not fired yet, in
// list order.
function due(listeners, elapsedSec, triggered) {
    var out = [];
    var n = listeners ? listeners.length : 0;
    for (var i = 0; i < n; i++) {
        if (elapsedSec >= listenerSeconds(listeners[i]) && (triggered || []).indexOf(i) < 0)
            out.push(i);
    }
    return out;
}
