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

SERVICES = {
    "Battery": BATTERY,
    "PowerProfileClient": POWER_PROFILES,
}
