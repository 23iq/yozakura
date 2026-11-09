"""Live activities around the bar's center content (modules/bar/activities/
ActivityHost.qml) offscreen. With the notch off they sit in the middle of the
bar's edge; a center tab/group/dock there (the Emaki preset's taskbar island)
must push them aside instead of being covered (a mic tab over the taskbar
icons was the bug)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("activity-host-center")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property int roundness: 10
    property string notchPosition: "top"
    property string notchTheme: "default"
    property var bar: ({ frameEnabled: false, frameThickness: 6 })
}""")
h.module("qs.modules.theme", {
    "Styling": "pragma Singleton\nQtObject { function fontSize(o) { return 14 + o } function radius(o) { return 10 + o } }",
    "BarMetrics": """pragma Singleton
QtObject {
    property int moduleSize: 36; property int notchRestHeight: 40; property int notchIslandHeight: 36
    property int islandPadding: 2; property bool compact: false
    function iconSize(b) { return b }
}""",
})
h.singleton("qs.modules.services", "ShellLayout", "QtObject { property bool notchEnabled: false }")
h.singleton("qs.modules.services", "Visibilities", """QtObject {
    property real notchW: 0
    function notchRect(s) { return Qt.rect(0, 0, notchW, notchW > 0 ? 36 : 0) }
}""")
h.singleton("qs.modules.services.activities", "ActivityService", """QtObject {
    property string presentation: "islands"
    property int count: 1
}""")
# The bar on the bottom edge: islands style with a center tab of 400 px
# (its fillets 14 px each), start tab reaching 300 px, end tab 350 px
h.module("qs.modules.bar", {"BarContent": """Item {
    property var styleMeta: ({ activity: "tab" })
    property string barPosition: "bottom"
    property bool reveal: true
    property bool activeWindowFullscreen: false
    property real startExtent: 300
    property real endExtent: 350
    property real islandFillet: 14
    property real centerReach: 214
    readonly property real centerStart: 1000 - centerReach
    readonly property real centerEnd: 1000 + centerReach
    property real totalBarWidth: 0
    property real totalBarHeight: 40
    property real barTargetHeight: 40
}"""})
h.module("qs.modules.notch", {"NotchContent": "Item { property bool screenNotchOpen; property bool reveal: true; property bool activeWindowFullscreen }"})
h.copy("modules/bar/activities/ActivityHost.qml")
# Only the spans matter here; ActivityGaps itself has tests/activity-islands.test.py
h.stub("ActivityGaps", """Item {
    property string screenName; property string mode; property string edge; property bool revealed
    property real notchStart; property real notchEnd; property real leftLimit; property real rightLimit
    property real edgeOffset; property real thickness; property real fillet; property real cornerRadius
    property real gap; property real spacing; property int indicatorSize; property int fontSize
    property Item leftHitboxItem: null; property Item rightHitboxItem: null
}""")

root = h.load("""
import QtQuick
import qs.modules.bar
import qs.modules.services
Item {
    function setNotch(w) { Visibilities.notchW = w; }
    width: 2000; height: 200
    BarContent { id: barItem; objectName: "bar" }
    ActivityHost {
        objectName: "host"
        anchors.fill: parent
        screenName: "DP-1"
        bar: barItem
    }
}
""")
host = h.find(root, "host")
bar = h.find(root, "bar")

assert h.eval(host, "place.mode") == "tab", h.eval(host, "place.mode")
assert h.eval(host, "place.sameEdge"), "notch off: the activities follow the bar's edge"
# Notch off, center tab present: the middle span is the tab, not the screen center
assert abs(h.eval(host, "notchStart") - 786) < 0.5, h.eval(host, "notchStart")
assert abs(h.eval(host, "notchEnd") - 1214) < 0.5, h.eval(host, "notchEnd")
gaps = h.eval(host, "gapsItem !== null")
assert gaps, "a wanted activity loads ActivityGaps"
assert abs(h.eval(host, "gapsItem.notchEnd") - 1214) < 0.5, "ActivityGaps gets the widened middle"

# No center content: the middle of the edge again
h.eval(bar, "centerReach = 0")
assert abs(h.eval(host, "notchStart") - 1000) < 0.5, h.eval(host, "notchStart")
assert abs(h.eval(host, "notchEnd") - 1000) < 0.5, h.eval(host, "notchEnd")

# A notch wider than the center content wins
h.eval(bar, "centerReach = 100")
h.eval(root, "setNotch(600)")
assert abs(h.eval(host, "notchStart") - 700) < 0.5, h.eval(host, "notchStart")
assert abs(h.eval(host, "notchEnd") - 1300) < 0.5, h.eval(host, "notchEnd")

print("activity host: activities go around the bar's center content")
h.exit(0)
