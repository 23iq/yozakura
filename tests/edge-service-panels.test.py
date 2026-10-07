"""Real EdgeService respects screen-specific panels and measured style depth."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("edge-service-panels")
h.module("Quickshell", {"Singleton": "QtObject {}"})
h.singleton("Quickshell", "Quickshell", 'QtObject { property var screens: [{name: "A"}, {name: "B"}] }')
h.singleton("qs.config", "Config", '''QtObject {
    property var bar: ({position: "top", frameEnabled: false, panels: [
        {id: "rail", edge: "right", style: "classic", thickness: 80, margin: 12, screens: ["A"]},
        {id: "status", edge: "bottom", style: "statusline", thickness: 24, screens: ["secondary"]}
    ]})
    property var dock: ({enabled: false})
    property var notch: ({enabled: false})
}''')
h.singleton("qs.modules.theme", "BarMetrics", "QtObject { property int moduleSize: 40; property int notchRestHeight: 36 }")
h.copy("modules/shell/EdgeService.qml", "qs/modules/shell")
h.module("qs.modules.shell", {})
r = h.load('''import QtQuick
import qs.modules.shell
Item {
    property var a: ({name: "A", width: 1920, height: 1080})
    property var b: ({name: "B", width: 1920, height: 1080})
}''', auto_stub=False)


def ev(expr):
    return json.loads(h.eval(r, f"JSON.stringify({expr})"))


assert ev("EdgeService.insets(a)") == dict(top=0, right=92, bottom=0, left=0)
assert ev("EdgeService.insets(b)") == dict(top=0, right=0, bottom=24, left=0)
assert ev('EdgeService.sheetRect(a, "right", 932)')["x"] == 896
h.eval(r, 'EdgeService.setPanels("A", [{pos: "right", size: 118}, {pos: "top", size: 52}])')
assert ev("EdgeService.insets(a)") == dict(top=52, right=118, bottom=0, left=0)
assert ev("EdgeService.insets(a, {bar: false})") == dict(top=0, right=0, bottom=0, left=0)
h.eval(r, 'EdgeService.setPanels("A", [])')
assert ev("EdgeService.workArea(a)") == dict(x=0, y=0, w=1920, h=1080)
h.eval(r, 'EdgeService.setPanels("A", null)')
assert ev("EdgeService.insets(a)")["right"] == 92
print("edge-service-panels: ok")
h.exit(0)
