.pragma library

// "Try the new Yozakura look" (TryNewLookCard, PresetNewLook): offered once
// to existing users (onboarding done) whose active set is not the new
// default. "Try" previews the set (`preset apply --preview`) with a 30 s
// Keep / Revert countdown, like the displays keep/revert; Keep applies it
// for real, Revert or the timeout runs `preset revert`. Any answer ("Not
// now" too) marks it offered forever (general.newLookOffered).
//
// The flow is a pure state machine: step(phase, event) ->
//   {phase, run: `<app> preset` argv to run | null, mark: set the flag}
// phases: idle -> starting -> trying -> ending -> done.

var TARGET = "Yozakura";
var SECONDS = 30;
// Names the backend resolves to the target (the old default set).
var ALIASES = ["yozakura", "yozakura default"];

function isTarget(name) {
    return ALIASES.indexOf(String(name || "").trim().toLowerCase()) !== -1;
}

// general: {onboardingDone, newLookOffered}; active: the active set name
// ("" while unknown: nothing is offered until the list is loaded).
function shouldOffer(general, active) {
    var g = general || {};
    if (g.onboardingDone !== true || g.newLookOffered === true)
        return false;
    return !!active && !isTarget(active);
}

function tryArgs() {
    return ["apply", "--preview", TARGET];
}

function keepArgs() {
    return ["apply", TARGET];
}

function revertArgs() {
    return ["revert"];
}

function step(phase, event) {
    var same = {
        "phase": phase,
        "run": null,
        "mark": false
    };
    switch (phase) {
    case "idle":
        if (event === "try")
            return {
                "phase": "starting",
                "run": tryArgs(),
                "mark": false
            };
        if (event === "dismiss")
            return {
                "phase": "done",
                "run": null,
                "mark": true
            };
        return same;
    case "starting":
        if (event === "ok")
            return {
                "phase": "trying",
                "run": null,
                "mark": false
            };
        // The preview failed: nothing changed, offer it again.
        if (event === "fail")
            return {
                "phase": "idle",
                "run": null,
                "mark": false
            };
        return same;
    case "trying":
        if (event === "keep")
            return {
                "phase": "ending",
                "run": keepArgs(),
                "mark": false
            };
        if (event === "revert" || event === "timeout")
            return {
                "phase": "ending",
                "run": revertArgs(),
                "mark": false
            };
        return same;
    case "ending":
        if (event === "ok" || event === "fail")
            return {
                "phase": "done",
                "run": null,
                "mark": true
            };
        return same;
    }
    return same;
}

// Whole seconds left of a `seconds` countdown started at `startedMs`.
function remaining(startedMs, nowMs, seconds) {
    var total = seconds === undefined ? SECONDS : seconds;
    return Math.max(0, Math.ceil(total - (nowMs - startedMs) / 1000));
}

// 1 -> 0 as the countdown runs out (the card's progress line).
function fraction(left, seconds) {
    var total = seconds === undefined ? SECONDS : seconds;
    return total > 0 ? Math.max(0, Math.min(1, left / total)) : 0;
}
