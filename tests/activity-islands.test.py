"""Live activity islands (modules/bar/activities/ActivityGaps.qml) offscreen:
sides, overflow, reveal, and that removed activities retract before their
delegate goes away."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("activity-islands")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property int roundness: 12
    property var theme: ({ font: "Sans", fontSize: 14 })
}""")
h.module("qs.modules.theme", {
    "Styling": "pragma Singleton\nQtObject { function fontSize(o) { return 14 + o } function radius(o) { return 12 + o } function srItem(v) { return \"white\" } }",
    "Colors": "pragma Singleton\nQtObject { property color overBackground: \"white\"; property color primary: \"pink\"; property color red: \"red\"; property color yellow: \"yellow\" }",
    "Icons": "pragma Singleton\nQtObject { property string font: \"Sans\" }",
})
h.module("qs.modules.bar", {"IslandShape": """Item {
    property string edge; property real bodyLength; property real bodyThickness
    property real fillet; property real bodyRadius
    readonly property real bodyOffset: fillet
    readonly property real localHeight: bodyThickness
}"""})
h.module("qs.modules.components", {
    "StyledRect": "Rectangle { property string variant; property bool animateRadius; property color item: \"white\" }",
    "StyledToolTip": "Item { property string tooltipText; property bool show }",
})
h.module("Quickshell.Widgets", {"IconImage": "Image { property real implicitSize }"})
h.singleton("qs.modules.services.activities", "ActivityService", """QtObject {
    property var activities: []
    property int maxVisible: 4
    readonly property int count: activities.length
    property var lastActivated: null
    function activate(a, button, screen) { lastActivated = a; }
}""")
h.copy("modules/bar/activities/ActivityGaps.qml")

root = h.load("""
import QtQuick
import qs.config
import qs.modules.services.activities
Item {
    width: 2000; height: 100
    ActivityGaps {
        objectName: "gaps"
        anchors.fill: parent
        notchStart: 800; notchEnd: 1200
        leftLimit: 100; rightLimit: 1900
        thickness: 30; fillet: 10; gap: 6; spacing: 6
    }
    function set(list) { ActivityService.activities = list; }
}
""")
gaps = h.find(root, "gaps")


def act(id_, category, label="x", priority=50):
    return f"({{ id: '{id_}', category: '{category}', priority: {priority}, label: '{label}', indicator: 'glyph', icon: '', image: '', detail: '{id_} detail', progress: -1, color: 'primary', startedAt: 0, action: '' }})"


def islands():
    joined = h.eval(gaps, "children.filter(c => c.aid !== undefined).map(c => c.aid + ':' + c.shown).join(',')")
    return [x for x in joined.split(",") if x]


def settle(ms=30):
    QTest.qWait(ms)


assert h.eval(gaps, "idle"), "no activities: nothing instantiated"

h.eval(root, f"set([{act('rec', 'privacy', '02:13', 100)}, {act('timer', 'task', '18:42', 50)}])")
settle()
assert sorted(islands()) == ["rec:true", "timer:true"], islands()
xs = h.eval(gaps, "JSON.stringify(xs)")
assert '"rec":1206' in xs, xs  # privacy: right of the notch, gap 6 from its end
left_x = h.eval(gaps, "xs.timer")
width_timer = h.eval(gaps, "widths.timer")
assert abs(left_x + width_timer - 794) < 0.5, (left_x, width_timer)  # task: left, ends gap 6 before the notch

# Overflow: maxVisible 1 keeps the top island and collapses the rest into +N
h.eval(root, "ActivityService.maxVisible = 1")
settle()
assert sorted(islands()) == ["rec:true", "timer:false"], islands()
assert h.eval(gaps, "result.overflow.ids.join(',')") == "timer"
h.eval(root, "ActivityService.maxVisible = 4")
settle()
assert h.eval(gaps, "result.overflow") is None

# Hidden notch: islands retract but stay alive
gaps.setProperty("revealed", False)
settle()
assert sorted(islands()) == ["rec:false", "timer:false"], islands()
assert h.eval(gaps, "leftBounds.width") == 0, "no input region while hidden"
gaps.setProperty("revealed", True)
settle()

# Removal with animations off: the delegate goes immediately
h.eval(root, f"set([{act('rec', 'privacy', '02:13', 100)}])")
settle()
assert islands() == ["rec:true"], islands()

# Removal with animations on: retracts first, then the delegate is dropped
h.eval(root, "Config.animDuration = 200")
h.eval(root, f"set([{act('rec', 'privacy', '02:13', 100)}, {act('mic', 'privacy', 'Firefox', 70)}])")
QTest.qWait(400)
assert sorted(islands()) == ["mic:true", "rec:true"], islands()
h.eval(root, f"set([{act('mic', 'privacy', 'Firefox', 70)}])")
settle(20)
assert "rec:false" in islands(), "removed island must retract, not vanish"
QTest.qWait(400)
assert islands() == ["mic:true"], islands()
assert abs(h.eval(gaps, "xs.mic") - 1206) < 0.5, "remaining island slides next to the notch"

# Clicks are routed to the service with the activity object
h.eval(gaps, "children.filter(c => c.aid === 'mic')[0].clicked(Qt.RightButton)")
assert h.eval(root, "ActivityService.lastActivated.id") == "mic"

print("activity islands: sides, overflow, reveal, retract and click routing passed")
