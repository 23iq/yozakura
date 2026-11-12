.pragma library

// When a video wallpaper holds playback (Wallpaper.qml videoPaused).
// `state`: {locked, fullscreen, covered, idleSeconds, onBattery};
// `perf`: Config.performance (missing keys use the defaults of
// config/defaults/performance.js). Tested in tests/wallpaper-pause.test.cjs.

var DEFAULT_IDLE_DELAY = 60;

function _on(value, fallback) {
    return value === undefined || value === null ? fallback : !!value;
}

// Idle seconds after which the wallpaper pauses, or 0 when idle pausing is
// off. IdleService wakes at this threshold so `idleSeconds` reaches it.
function idleDelay(perf) {
    var p = perf || {};
    if (!_on(p.pauseWallpaperOnIdle, true))
        return 0;
    var delay = Number(p.pauseWallpaperIdleDelay);
    return delay > 0 ? delay : DEFAULT_IDLE_DELAY;
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
    var delay = idleDelay(p);
    if (delay > 0 && (Number(s.idleSeconds) || 0) >= delay)
        return true;
    return !!s.onBattery && _on(p.pauseWallpaperOnBattery, false);
}
