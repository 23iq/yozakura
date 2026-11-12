.pragma library

// The wallpaper idle-pause delay, shared by the video wallpaper
// (widgets/dashboard/wallpapers/WallpaperPause.js), which pauses once idle
// this long, and IdleService, which wakes at it so its idle seconds reach it.
// Lives at services level so neither side imports upward. `perf`:
// Config.performance (missing keys use the defaults of
// config/defaults/performance.js). Tested in tests/wallpaper-pause.test.cjs.

var DEFAULT_IDLE_DELAY = 60;

// Idle seconds after which the wallpaper pauses, or 0 when idle pausing is off.
function idleDelay(perf) {
    var p = perf || {};
    var on = p.pauseWallpaperOnIdle;
    if (on !== undefined && on !== null && !on)
        return 0;
    var delay = Number(p.pauseWallpaperIdleDelay);
    return delay > 0 ? delay : DEFAULT_IDLE_DELAY;
}
