.pragma library

// When the battery saver holds decorative per-frame work (BatterySaver.qml):
// the audio visualizer (no cava consumer), the wavy media progress line and
// video wallpapers (WallpaperPause.js). Tested in tests/battery-saver.test.cjs.
//
// enabled     performance.batterySaver (opt-in, default false)
// hasBattery  the UPower display device is a battery (false on a desktop)
// onBattery   UPower reports the machine runs from it (false on AC)
function active(enabled, hasBattery, onBattery) {
    return enabled === true && hasBattery === true && onBattery === true;
}
