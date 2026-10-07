.pragma library

// Pure text / glyph helpers shared by the bento widgets and the bar clock
// popup (tests/widget-format.test.cjs). `tr(key, ...args)` translates
// (I18n.t); helpers that take it never hard-code words.

// Icons.* name of a WMO weather code (Open-Meteo `weathercode`).
function weatherGlyph(code, isDay) {
    var c = Number(code) || 0;
    var day = isDay !== false;
    if (c === 0)
        return day ? "sun" : "moon";
    if (c === 1 || c === 2)
        return day ? "cloudSun" : "cloudMoon";
    if (c === 3)
        return "cloud";
    if (c === 45 || c === 48)
        return "cloudFog";
    if ((c >= 71 && c <= 77) || c === 85 || c === 86)
        return "cloudSnow";
    if (c >= 95)
        return "cloudLightning";
    if (c >= 51)
        return "cloudRain";
    return "cloud";
}

// "18°" (rounded; "-0" reads "0").
function temp(t) {
    var n = Math.round(Number(t) || 0);
    return (n === 0 ? 0 : n) + "°";
}

// Caption under the weather: "H 21° · L 12° · Rain 40% · Wind 12 km/h".
// `rain` < 0 / null and `wind` null are left out.
function weatherDetails(w, tr) {
    if (!w)
        return "";
    var parts = [tr("clock.panel.high_low", temp(w.max), temp(w.min))];
    if (w.rain !== null && w.rain !== undefined && Number(w.rain) >= 0)
        parts.push(tr("clock.panel.rain", Math.round(Number(w.rain))));
    if (w.wind !== null && w.wind !== undefined)
        parts.push(tr("clock.panel.wind", Math.round(Number(w.wind) || 0)));
    return parts.join(" · ");
}

// Zone offset against the local one, in minutes east of UTC: "+6h",
// "−3h30", "0h".
function offsetLabel(zoneMinutes, localMinutes) {
    if (zoneMinutes === null || zoneMinutes === undefined)
        return "";
    var d = Number(zoneMinutes) - Number(localMinutes || 0);
    if (d === 0)
        return "0h";
    var sign = d > 0 ? "+" : "−";
    var a = Math.abs(d);
    var h = Math.floor(a / 60);
    var m = a % 60;
    return sign + h + "h" + (m ? (m < 10 ? "0" : "") + m : "");
}

// Track position: "1:44", "1:02:03".
function mediaTime(seconds) {
    var s = Math.max(0, Math.floor(Number(seconds) || 0));
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var r = s % 60;
    var ss = (r < 10 ? "0" : "") + r;
    if (h > 0)
        return h + ":" + (m < 10 ? "0" : "") + m + ":" + ss;
    return m + ":" + ss;
}

// Phase of a Pomodoro timer view ({pomodoro: {phase, round, every}}):
// {phase: "work" | "break" | "longBreak", round, every}. Idle (no timer):
// the first work round.
function pomodoroPhase(pomo) {
    var p = pomo && pomo.pomodoro ? pomo.pomodoro : null;
    var phase = p && (p.phase === "break" || p.phase === "longBreak") ? p.phase : "work";
    return {
        "phase": phase,
        "round": p && p.round > 0 ? p.round : 1,
        "every": p && p.every > 0 ? p.every : 4
    };
}

// "FOCUS · 1 OF 4" (the label role uppercases it), "BREAK", "LONG BREAK".
function pomodoroLabel(pomo, tr) {
    var s = pomodoroPhase(pomo);
    if (s.phase !== "work")
        return tr(s.phase === "longBreak" ? "clock.panel.long_break" : "clock.panel.break");
    return tr("clock.panel.focus") + " · " + tr("clock.panel.round_of", s.round, s.every);
}
