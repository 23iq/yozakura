"""OsdService routes audio/brightness events by style, shows device switches
and a distinct mute state; styles fall back when their host is missing."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("osd")
h.singleton("Quickshell", "Quickshell", "QtObject {}")
h.singleton("qs.config", "Config", """QtObject {
    property QtObject layout: QtObject {
        property QtObject osd: QtObject { property string style: "pill"; property int timeout: 2500 }
    }
}""")
h.singleton("qs.modules.services", "Audio", """QtObject {
    id: a
    property var sink: ({ ready: true, description: "Speakers", audio: { volume: 0.4, muted: false } })
    property var source: null
    property real lastSet: -1
    signal volumeChanged(real volume, bool muted, var node)
    signal micVolumeChanged(real volume, bool muted, var node)
    function setVolume(v) { lastSet = v }
    function setMicVolume(v) {}
}""")
h.singleton("qs.modules.services", "Brightness", """QtObject {
    property bool syncBrightness: false
    signal brightnessChanged(real value, var screen)
    function getMonitorForScreen(s) { return null }
}""")
h.copy("modules/shell/osd/OsdStyles.js")
h.copy("modules/shell/osd/MicrophoneVolume.js")
h.copy("modules/services/OsdService.qml", strip_singleton=True, siblings=False, replace={
    "Singleton {": "Item {",
    "import Quickshell\n": "",
    "../shell/osd/OsdStyles.js": "OsdStyles.js",
    "../shell/osd/MicrophoneVolume.js": "MicrophoneVolume.js",
})
root = h.load('''Item {
    property QtObject svc: OsdService { objectName: "svc" }
    property var seen: []
    property var island: []
    property var inline: []
    Connections { target: svc
        function onLevel(k, v, m, d) { seen = seen.concat([[k, v, m, d]]) }
        function onToIsland(k, v, m, d) { island = island.concat([[k, v, m, d]]) }
        function onInlineRequest(k) { inline = inline.concat([k]) }
    }
}''', auto_stub=False)
svc = h.find(root, "svc")
audio = h.engine.singletonInstance("qs.modules.services", "Audio")
bright = h.engine.singletonInstance("qs.modules.services", "Brightness")
cfg = h.engine.singletonInstance("qs.config", "Config")


def count(name):
    return h.eval(root, f"{name}.length")


# Volume event: level fires, no island/inline in pill style.
audio.volumeChanged.emit(0.5, False, None)
assert count("seen") == 1 and count("island") == 0 and count("inline") == 0
assert h.eval(root, "seen[0][0]") == "volume" and h.eval(root, "seen[0][3]") == ""

# Mute is a distinct state, carried through unchanged.
audio.volumeChanged.emit(0.5, True, None)
assert h.eval(root, "seen[1][2]") is True

# Brightness reports the screen for per-screen filtering.
class Screen:
    name = "DP-1"
bright.brightnessChanged.emit(0.7, None)
assert h.eval(root, "seen[2][0]") == "brightness"

# Island style also emits toIsland.
cfg.property("layout").property("osd").setProperty("style", "island")
audio.volumeChanged.emit(0.3, False, None)
assert count("island") == 1

# bar-inline without a bar widget falls back to the pill window...
cfg.property("layout").property("osd").setProperty("style", "bar-inline")
assert h.eval(svc, "route.style") == "pill" and h.eval(svc, "route.window") is True
audio.volumeChanged.emit(0.3, False, None)
assert count("inline") == 0
# ...and with a registered widget it asks the bar to expand instead.
h.eval(svc, "registerInline(true)")
assert h.eval(svc, "route.style") == "bar-inline" and h.eval(svc, "route.window") is False
audio.volumeChanged.emit(0.35, False, None)
assert count("inline") == 1 and h.eval(root, "inline[0]") == "volume"
h.eval(svc, "registerInline(false)")
assert h.eval(svc, "route.style") == "pill"

# Output switch carries the device name once.
audio.setProperty("sink", {"ready": True, "description": "Headphones", "audio": {"volume": 0.4, "muted": False}})
assert h.eval(root, "seen[seen.length - 1][3]") == "Headphones", h.eval(root, "JSON.stringify(seen)")

# Scrolling asks Audio for a clamped level.
h.eval(svc, 'adjust("volume", 0.05, null)')
assert abs(audio.property("lastSet") - 0.45) < 1e-6, audio.property("lastSet")
h.eval(svc, 'adjust("volume", 5, null)')
assert audio.property("lastSet") == 1

# Unknown style normalises; animDuration 0 never breaks routing.
cfg.property("layout").property("osd").setProperty("style", "minimal")
assert h.eval(svc, "style") == "pill"
h.exit(0)
