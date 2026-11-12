.pragma library
.import "../../../services/WallpaperIdleDelay.js" as IdleDelay

// When a video wallpaper holds playback (Wallpaper.qml videoPaused).
// `state`: {locked, fullscreen, covered, idleSeconds, onBattery, batterySaver};
// `perf`: Config.performance (missing keys use the defaults of
// config/defaults/performance.js). Tested in tests/wallpaper-pause.test.cjs.

function _on(value, fallback) {
    return value === undefined || value === null ? fallback : !!value;
}

function shouldPause(state, perf) {
    var s = state || {};
    var p = perf || {};
    if (s.locked)
        return true;
    if (s.fullscreen && _on(p.pauseWallpaperOnFullscreen, true))
        return true;
    if (s.covered)
        return true;
    // The idle-pause delay (services/WallpaperIdleDelay.js), which
    // IdleService also wakes at.
    var delay = IdleDelay.idleDelay(p);
    if (delay > 0 && (Number(s.idleSeconds) || 0) >= delay)
        return true;
    // An active battery saver (BatterySaver.active) pauses like the opt-in.
    return !!s.onBattery && (!!s.batterySaver || _on(p.pauseWallpaperOnBattery, false));
}
