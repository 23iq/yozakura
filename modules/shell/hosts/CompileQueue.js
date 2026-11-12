.pragma library

// Idle-time compile warm-up (CompileWarmUp.qml). Quickshell serves the shell
// from its VFS, where Qt keeps no QML disk cache, so every file is compiled
// the first time it is loaded in a session. These rarely opened, heavy entry
// points are compiled (never instantiated) in the background, one at a time,
// so their first open only pays object creation. Tested in
// tests/compile-warm-up.test.cjs.

// Paths from the repository root, in the order they are compiled: the most
// likely first opens first.
var ENTRIES = [
    "modules/widgets/dashboard/DashboardView.qml",
    "modules/widgets/overview/OverviewPopup.qml",
    "modules/settings/SettingsWindow.qml",
    "modules/widgets/presets/PresetsPopup.qml"
];

// After startup (the launcher pre-creation runs at ~3 s, services settle).
var START_DELAY = 8000;
// Between two entries, so the work stays spread out.
var GAP = 1500;
// Retry delay while a window is open or opening.
var BUSY_RETRY = 3000;

// Component.status values (QtQml Component enum).
var NULL = 0;
var READY = 1;
var LOADING = 2;
var ERROR = 3;

// `timing` (optional, tests shorten it): {startDelay, gap, busyRetry}.
function _timing(timing) {
    var t = timing || {};
    return {
        "startDelay": t.startDelay > 0 ? t.startDelay : START_DELAY,
        "gap": t.gap > 0 ? t.gap : GAP,
        "busyRetry": t.busyRetry > 0 ? t.busyRetry : BUSY_RETRY
    };
}

// What the queue does next.
// state: {enabled, index, count, busy, pending}
//   enabled  performance.warmViews
//   index    next entry to compile
//   count    number of entries
//   busy     a window is open or opening right now
//   pending  an entry is still compiling
// Returns {action: "stop" | "wait" | "compile", delay}: "wait" asks to look
// again after `delay` ms; "compile" compiles entry `index` now.
function next(state, timing) {
    var s = state || {};
    var t = _timing(timing);
    var count = Number(s.count) || 0;
    var index = Number(s.index) || 0;
    if (s.enabled !== true || index >= count)
        return {
            "action": "stop",
            "delay": 0
        };
    if (s.pending)
        return {
            "action": "wait",
            "delay": t.gap
        };
    if (s.busy)
        return {
            "action": "wait",
            "delay": t.busyRetry
        };
    return {
        "action": "compile",
        "delay": 0
    };
}

// Delay before looking at entry `index` (the first one waits for startup).
function delayBefore(index, timing) {
    var t = _timing(timing);
    return index > 0 ? t.gap : t.startDelay;
}

// True once a component finished loading (ready or failed).
function settled(status) {
    return status === READY || status === ERROR || status === NULL;
}
