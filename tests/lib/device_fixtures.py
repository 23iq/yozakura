"""Believable device state for offscreen settings renders and tests.

The device pages of the settings window (Power, Displays, Keys, Network,
Bluetooth, Sound) read live services (UPower, power-profiles, NetworkManager,
BlueZ, PipeWire, the daemon's displays / keyboard services) that do not exist
in the harness, so they render empty there. These stand-ins carry a small,
fixed world - a laptop at 76 % on Balanced, two monitors, two keyboard
layouts, a few Wi-Fi networks and Bluetooth devices, speakers and a
microphone with two apps playing - so a page's look can be reviewed and its
behaviour tested. Fixtures only: nothing here is product code.

    SettingsEnv(..., devices=True)        # tests/lib/settings_env.py
    tools/render/settings_render.py --devices ...

Every stub records the calls a page makes (`calls`) instead of acting.
"""
from __future__ import annotations

import json

BATTERY = """pragma Singleton
import QtQuick
import qs.modules.theme
QtObject {
    property bool available: true
    property real percentage: 76
    property bool isCharging: false
    property bool isPluggedIn: false
    property bool onBattery: true
    property string timeToEmpty: "3 h 12 min"
    property string timeToFull: ""
    function getBatteryIcon() { return Icons.batteryHigh }
}"""

POWER_PROFILES = """pragma Singleton
import QtQuick
QtObject {
    property var availableProfiles: ["power-saver", "balanced", "performance"]
    property string currentProfile: "balanced"
    property bool isAvailable: true
    property var calls: []
    function setProfile(p) { calls = calls.concat([p]); currentProfile = p }
}"""

# Two monitors side by side: a 27" Dell (DP-1, 2560x1440 at 60 Hz, 240 Hz
# and 4K available) and a 27" LG at 144 Hz (the world of
# tests/lib/displays_env.py).
OUTPUTS = [
    {"id": "DEL-U2723QE-1", "name": "DP-1", "make": "Dell", "model": "U2723QE", "enabled": True,
     "width": 2560, "height": 1440, "refresh": 60, "x": 0, "y": 0, "scale": 1, "transform": 0, "vrr": False,
     "physical_width_mm": 597, "physical_height_mm": 336,
     "modes": [{"width": w, "height": h, "refresh": r}
               for (w, h, rates) in [(3840, 2160, [60, 30]), (2560, 1440, [240, 144, 120, 60]),
                                     (1920, 1080, [240, 144, 60]), (1280, 720, [60])] for r in rates]},
    {"id": "LG-27GL-2", "name": "HDMI-A-1", "make": "LG", "model": "27GL850", "enabled": True,
     "width": 1920, "height": 1080, "refresh": 144, "x": 2560, "y": 180, "scale": 1, "transform": 0, "vrr": False,
     "physical_width_mm": 598, "physical_height_mm": 336,
     "modes": [{"width": 1920, "height": 1080, "refresh": r} for r in (144, 120, 60)]
              + [{"width": 1280, "height": 720, "refresh": 60}]},
]

# The daemon's displays service (modules/services/DisplaysService.qml): the
# live outputs; apply starts a 15 s session like the real one; every call
# is recorded.
DISPLAYS = """pragma Singleton
import QtQuick
import "DisplayModel.js" as DisplayModel
QtObject {
    property var outputs: %s
    property var session: ({ "id": "", "state": "", "remaining": 0, "live": true })
    readonly property bool pending: session.state === "pending"
    property var identified: []
    property var conflicts: []
    property var moveSkipped: []
    property bool applying: false
    property var notice: ({ "kind": "", "message": "" })
    property var calls: []
    signal applyFailed(string message)
    function refresh() {}
    function currentConfigs() { return outputs.map(o => DisplayModel.outputToConfig(o, null)) }
    function apply(c) { calls = calls.concat([["apply", c]]); session = { "id": "s1", "state": "pending", "remaining": 15, "live": true } }
    function keep() { calls = calls.concat([["keep"]]); session = { "id": "", "state": "", "remaining": 0, "live": true } }
    function revert() { calls = calls.concat([["revert"]]); session = { "id": "", "state": "", "remaining": 0, "live": true } }
    function identify() { calls = calls.concat([["identify"]]) }
    function scanConflicts() {}
    function moveConflicts() {}
    function dismissNotice() { notice = { "kind": "", "message": "" } }
}""" % json.dumps(OUTPUTS)

# Night light (modules/services/NightLightClient.qml).
NIGHT_LIGHT = """pragma Singleton
import QtQuick
QtObject {
    property bool active: false
    property int temp: 4500
    property var calls: []
    function toggle() { setEnabled(!active) }
    function setEnabled(v) { calls = calls.concat([["enabled", v]]); active = v }
    function setTemperature(v) { calls = calls.concat([["temp", v]]); temp = v }
}"""

SERVICES = {
    "Battery": BATTERY,
    "PowerProfileClient": POWER_PROFILES,
    "DisplaysService": DISPLAYS,
    "NightLightClient": NIGHT_LIGHT,
}
