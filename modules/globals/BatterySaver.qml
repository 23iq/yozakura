pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import "BatterySaverRule.js" as Rule

// The one "battery saver is active right now" switch (performance.batterySaver
// while the machine runs on battery). Decorative per-frame work reads it:
// NotchVisualizer and BorderPulse (neither registers with cava),
// PositionSlider (straight line) and the video wallpaper (WallpaperPause.js). Lives in globals so the
// foundation components can read it; the battery test mirrors the services'
// Battery.onBattery. UPower is only read once the saver is turned on.
Singleton {
    id: root

    readonly property bool enabled: Config.performance ? Config.performance.batterySaver === true : false
    readonly property bool hasBattery: root.enabled && UPower.displayDevice !== null && UPower.displayDevice.type === UPowerDeviceType.Battery
    readonly property bool onBattery: root.hasBattery && UPower.onBattery
    readonly property bool active: Rule.active(root.enabled, root.hasBattery, root.onBattery)
}
