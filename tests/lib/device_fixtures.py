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

# NetworkService: connected to "Sakura 5G", five more networks around.
NETWORKS = [
    {"ssid": "Sakura 5G", "strength": 86, "frequency": 5180, "security": "WPA2", "active": True},
    {"ssid": "Sakura", "strength": 72, "frequency": 2437, "security": "WPA2", "active": False},
    {"ssid": "Café Hanami", "strength": 58, "frequency": 2412, "security": "", "active": False},
    {"ssid": "Neighbour-5G", "strength": 41, "frequency": 5220, "security": "WPA3", "active": False},
    {"ssid": "Printer-DIRECT", "strength": 33, "frequency": 2462, "security": "WPA2", "active": False},
    {"ssid": "Library Guest", "strength": 18, "frequency": 2412, "security": "", "active": False},
]
NETWORK = """pragma Singleton
import QtQuick
import qs.modules.theme
QtObject {
    id: net
    property bool wifi: true
    property bool ethernet: false
    property bool wifiEnabled: true
    property bool wifiScanning: false
    property string wifiStatus: "connected"
    property var calls: []
    property var friendlyWifiNetworks: %s.map(n => Object.assign({ "askingPassword": false, "isSecure": n.security !== "" }, n))
    readonly property var active: friendlyWifiNetworks.find(n => n.active) || null
    readonly property string networkName: active ? active.ssid : ""
    readonly property int networkStrength: active ? active.strength : 0
    function enableWifi(on) { calls = calls.concat([["enable", on]]); wifiEnabled = on }
    function toggleWifi() { enableWifi(!wifiEnabled) }
    function rescanWifi() { calls = calls.concat([["rescan"]]) }
    function connectToWifiNetwork(ap) { calls = calls.concat([["connect", ap.ssid]]) }
    function disconnectWifiNetwork() { calls = calls.concat([["disconnect"]]) }
    function changePassword(ap, pw) { calls = calls.concat([["password", ap.ssid]]) }
    function wifiIconForStrength(s) { return s > 80 ? Icons.wifiHigh : s > 55 ? Icons.wifiMedium : Icons.wifiLow }
}""" % json.dumps(NETWORKS)

# BluetoothService: headphones and a mouse connected, a keyboard paired, a
# speaker nearby.
DEVICES = [
    {"address": "AC:80:0A:11:22:33", "name": "Sakura Buds", "icon": "audio-headset", "paired": True,
     "connected": True, "battery": 64},
    {"address": "D0:3E:07:44:55:66", "name": "MX Anywhere", "icon": "input-mouse", "paired": True,
     "connected": True, "battery": 90},
    {"address": "F4:73:35:77:88:99", "name": "Keychron K3", "icon": "input-keyboard", "paired": True,
     "connected": False, "battery": -1},
    {"address": "08:EB:ED:AA:BB:CC", "name": "Living room speaker", "icon": "audio-card", "paired": False,
     "connected": False, "battery": -1},
]
BLUETOOTH = """pragma Singleton
import QtQuick
QtObject {
    property bool enabled: true
    property bool discovering: false
    property var calls: []
    property var friendlyDeviceList: %s.map(d => Object.assign({ "connecting": false, "trusted": d.paired }, d))
    function setEnabled(v) { calls = calls.concat([["enabled", v]]); enabled = v }
    function startDiscovery() { discovering = true }
    function stopDiscovery() { discovering = false }
    function connectDevice(a) { calls = calls.concat([["connect", a]]) }
    function disconnectDevice(a) { calls = calls.concat([["disconnect", a]]) }
    function pairDevice(a) { calls = calls.concat([["pair", a]]) }
    function removeDevice(a) { calls = calls.concat([["remove", a]]) }
}""" % json.dumps(DEVICES)

# Audio (PipeWire): laptop speakers in use at 62 %, HDMI and headphones;
# the built-in microphone at 80 %; Spotify and Firefox playing.
AUDIO = """pragma Singleton
import QtQuick
import qs.modules.theme
QtObject {
    id: audio
    property var calls: []
    function node(id, name, desc, vol, extra) {
        return Object.assign({ "id": id, "name": name, "description": desc, "nickname": "", "ready": true,
                               "isStream": false, "properties": {}, "audio": { "volume": vol, "muted": false } }, extra || {})
    }
    property var outputDevices: [node(41, "alsa_output.speaker", "Speakers", 0.62),
                                 node(42, "alsa_output.hdmi", "HDMI · LG 27GL850", 1),
                                 node(43, "bluez_output.buds", "Sakura Buds headphones", 0.5)]
    property var inputDevices: [node(51, "alsa_input.mic", "Built-in microphone", 0.8),
                                node(52, "bluez_input.buds", "Sakura Buds headset", 0.7)]
    property var outputAppNodes: [node(61, "spotify", "Spotify", 0.9, { "isStream": true, "properties": { "application.name": "Spotify" } }),
                                  node(62, "firefox", "Firefox", 0.55, { "isStream": true, "properties": { "application.name": "Firefox" } })]
    property var inputAppNodes: []
    property var sink: outputDevices[0]
    property var source: inputDevices[0]
    function friendlyDeviceName(n) { return (n && (n.nickname || n.description)) || "Unknown" }
    function appNodeDisplayName(n) { return (n && n.properties && n.properties["application.name"]) || (n && n.description) || "Unknown" }
    function setVolume(v) { calls = calls.concat([["volume", v]]); sink = Object.assign({}, sink, { "audio": { "volume": v, "muted": sink.audio.muted } }) }
    function setMicVolume(v) { calls = calls.concat([["mic", v]]); source = Object.assign({}, source, { "audio": { "volume": v, "muted": source.audio.muted } }) }
    function setNodeVolume(n, v) { calls = calls.concat([["node", n.id, v]]) }
    function setDefaultSink(n) { calls = calls.concat([["sink", n.id]]); sink = n }
    function setDefaultSource(n) { calls = calls.concat([["source", n.id]]); source = n }
    function toggleMute() { calls = calls.concat([["mute"]]); sink = Object.assign({}, sink, { "audio": { "volume": sink.audio.volume, "muted": !sink.audio.muted } }) }
    function toggleMicMute() { calls = calls.concat([["micmute"]]) }
    function volumeIcon(volume, muted) { return muted ? Icons.speakerX : volume <= 0 ? Icons.speakerNone : volume < 0.33 ? Icons.speakerLow : Icons.speakerHigh }
}"""

# The visualizer's levels (CavaService): a song mid-chorus.
CAVA = """pragma Singleton
import QtQuick
QtObject {
    property bool available: true
    property var values: [0.42, 0.66, 0.71, 0.58, 0.49, 0.38, 0.31, 0.27]
    property var consumers: ({})
    function setConsumer(k, on) { var c = Object.assign({}, consumers); c[k] = on; consumers = c }
    function levels(n) { var o = []; for (var i = 0; i < n; i++) o.push(values[i % values.length]); return o }
}"""

EASY_EFFECTS = """pragma Singleton
import QtQuick
QtObject {
    property bool available: true
    property bool bypassed: false
    property var outputPresets: ["Loudness", "Bass boost", "Podcast", "Late night", "Flat"]
    property var inputPresets: ["Noise gate", "Voice", "Broadcast"]
    property string activeOutputPreset: "Loudness"
    property string activeInputPreset: "Noise gate"
    property var calls: []
    function setConsumer(k, on) {}
    function setBypass(v) { calls = calls.concat([["bypass", v]]); bypassed = v }
    function loadOutputPreset(n) { calls = calls.concat([["output", n]]); activeOutputPreset = n }
    function loadInputPreset(n) { calls = calls.concat([["input", n]]); activeInputPreset = n }
}"""

# KeyboardService: English (US) and Russian, Alt+Shift switches, Caps as
# Esc; the catalog of tests/lib/keyboard_env.py.
KEYBOARD = """pragma Singleton
import QtQuick
QtObject {
    property var catalog: %s
    property var active: ({ "name": "English (US)", "index": 0, "code": "us", "short": "EN" })
    readonly property string shortLabel: active.short
    readonly property bool indicatorVisible: true
    property bool managed: true
    property var current: null
    property bool known: true
    property bool unreadable: false
    property bool readFailed: false
    property string readError: ""
    property string applyError: ""
    property var effective: ({ "layouts": [{ "layout": "us", "variant": "" }, { "layout": "ru", "variant": "" }],
                               "switchBind": "alt_shift", "options": ["caps:escape"], "repeatRate": 30, "repeatDelay": 400 })
    property var calls: []
    function loadCatalog() {}
    function next() {}
    function refreshCurrent() {}
    function retryRead() {}
    function edit(patch) { calls = calls.concat([patch]); effective = Object.assign({}, effective, patch) }
    function takeOver() {}
    function apply() {}
}"""


def _catalog() -> str:
    from keyboard_env import CATALOG
    return json.dumps(CATALOG)


SERVICES = {
    "KeyboardService": KEYBOARD % _catalog(),
    "Audio": AUDIO,
    "CavaService": CAVA,
    "EasyEffectsService": EASY_EFFECTS,
    "NetworkService": NETWORK,
    "BluetoothService": BLUETOOTH,
    "Battery": BATTERY,
    "PowerProfileClient": POWER_PROFILES,
    "DisplaysService": DISPLAYS,
    "NightLightClient": NIGHT_LIGHT,
}
