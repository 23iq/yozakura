.pragma library
.import "../../services/timers/TimerFormat.js" as TimerFormat

// How the bar clock shows a running Pomodoro (bar.moduleOptions.clock.
// pomodoroStyle). `slot` says where PomodoroIndicator puts it: "inline"
// next to the face, "overlay" along the button edge, "none" for `island`,
// which leaves it to the notch timers activity (TimerActivity.qml).
var styles = [
    { id: "ring", url: "indicators/Ring.qml", slot: "inline", labelKey: "prefs.bar.pomodoro_style.ring" },
    { id: "underline", url: "indicators/Underline.qml", slot: "overlay", labelKey: "prefs.bar.pomodoro_style.underline" },
    { id: "countdown", url: "indicators/Countdown.qml", slot: "inline", labelKey: "prefs.bar.pomodoro_style.countdown" },
    { id: "island", url: "", slot: "none", labelKey: "prefs.bar.pomodoro_style.island" }
];

function ids() {
    return styles.map(function (s) { return s.id; });
}

function resolve(id) {
    for (var i = 0; i < styles.length; i++)
        if (styles[i].id === id)
            return styles[i];
    return styles[0];
}

// View state of TimersService.pomodoro (a TimerFormat.timerRows row or null).
// The label is always mm:ss (h:mm:ss past an hour) so its width is stable.
function state(p) {
    if (!p)
        return { "active": false, "progress": 0, "label": "", "phase": "", "ringing": false, "running": false };
    return {
        "active": true,
        "progress": Math.max(0, Math.min(1, Number(p.progress) || 0)),
        "label": TimerFormat.clock(p.leftMs),
        "phase": p.pomodoro && p.pomodoro.phase ? p.pomodoro.phase : "work",
        "ringing": !!p.ringing,
        "running": p.state === "running"
    };
}
