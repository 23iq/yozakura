"""Real inline hosts isolate unsynchronised monitor brightness events."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from osd_env import OsdEnv, OSD_SERVICE_STUB  # noqa: E402

env = OsdEnv("osd-inline-screen")
h = env.h
h.singleton("qs.modules.services", "OsdService", OSD_SERVICE_STUB)
h.singleton("qs.modules.services", "Brightness", "QtObject { property bool syncBrightness: false }")
root = h.load('''import QtQuick
import qs.modules.services
import qs.modules.shell.osd.styles
Item {
    width: 600; height: 100
    OsdBarInline { objectName: "a"; width: 280; height: 60; screen: ({name: "A"}) }
    OsdBarInline { objectName: "b"; x: 300; width: 280; height: 60; screen: ({name: "B"}) }
    function event(kind, value, screen) {
        OsdService.lastValue = value;
        OsdService.lastScreen = screen;
        OsdService.level(kind, value, false, "");
        OsdService.inlineRequest(kind);
    }
}''', auto_stub=False)
a, b = h.find(root, "a"), h.find(root, "b")
h.eval(root, 'event("brightness", 0.8, "B")')
assert b.property("shown") and b.property("value") == 0.8
assert not a.property("shown"), "brightness for B must not show on A"
h.eval(root, 'event("brightness", 0.25, "A")')
assert a.property("shown") and a.property("value") == 0.25
assert b.property("value") == 0.8, "A event must not corrupt B's slider delta baseline"
# The live slider computes its delta from B's own last brightness.
slider = next(child for child in b.findChildren(type(b)) if "LineSlider" in child.metaObject().className())
h.eval(slider, "moved(0.9)")
assert abs(h.eval(root, "OsdService.adjusted[0][1]") - 0.1) < 1e-6
h.eval(root, 'Brightness.syncBrightness = true; event("brightness", 0.4, "A")')
assert a.property("value") == b.property("value") == 0.4
h.eval(root, 'event("volume", 0.7, "")')
assert a.property("kind") == b.property("kind") == "volume"
assert a.property("value") == b.property("value") == 0.7
# A level of another kind without its request must not flip what is showing.
h.eval(root, 'OsdService.level("mic", 0.2, false, "")')
assert a.property("kind") == b.property("kind") == "volume"
assert a.property("value") == b.property("value") == 0.7
h.exit(0)
