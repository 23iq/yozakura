"""SettledScreens: hotplugged outputs get their windows only once settled.

The screens present at startup pass at once (the first start is not
delayed); a screen added later is let in only after the output list has held
still for `interval`, so no window is created on an output in the tick it
appears (QtWayland oldestEnteredScreen crash); a burst restarts the wait;
a removed screen leaves at once. shell.qml feeds the always-present
per-screen windows (wallpaper, desktop, panel with corners, OSD) from it.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

from PySide6.QtCore import QElapsedTimer  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
h = Harness("settled-screens")
h.copy("modules/components/SettledScreens.qml", "qs/modules/components", siblings=False)
h.module("qs.modules.components", {})

root = h.load("""import QtQuick
import qs.modules.components
Item {
    id: top
    QtObject { id: a; objectName: "A" }
    QtObject { id: b; objectName: "B" }
    QtObject { id: c; objectName: "C" }
    property var screens: [a, b]
    property alias settle: settle
    SettledScreens { id: settle; source: top.screens; interval: 120 }
    property int made: 0
    Instantiator {
        model: settle.screens
        delegate: QtObject { Component.onCompleted: top.made++ }
    }
    function names() { return settle.screens.map(s => s.objectName).join(","); }
    function plug(n) { screens = screens.concat([n === "B" ? b : c]); }
    function unplug(n) { screens = screens.filter(s => s.objectName !== n); }
}""", auto_stub=False)


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        h.app.processEvents()


def ev(expr):
    return h.eval(root, expr)


# Startup: the outputs present pass at once, windows made in the same tick.
assert ev("names()") == "A,B", ev("names()")
assert ev("made") == 2
assert ev("settle.settled") is True

# Hotplug: nothing is created in the tick the output appears.
ev('plug("C")')
assert ev("names()") == "A,B", "a hotplugged output got its windows at once"
assert ev("settle.settled") is False
pump(80)
# A burst (the new output removed and re-added) restarts the wait.
ev('unplug("C"); plug("C")')
pump(80)
assert ev("names()") == "A,B", "let in before the burst settled"
pump(100)
assert ev("names()") == "A,B,C", ev("names()")
assert ev("settle.settled") is True

# Unplug: gone at once (its windows go with the output).
ev('unplug("B")')
assert ev("names()") == "A,C", ev("names()")
assert ev("settle.settled") is True

# Removal while an addition waits: the removal is immediate, the addition not.
ev('plug("B"); unplug("A")')
assert ev("names()") == "C", ev("names()")
pump(200)
assert ev("names()") == "C,B", ev("names()")

# shell.qml: the always-present per-screen windows use the settled list.
shell = (REPO / "shell.qml").read_text()
for loader in ("wallpaperLoader", "desktopLoader", "screenShellContainer", "osdLoader"):
    m = re.search(r"Variants \{\n\s*model: (\S+)\n\n\s*\w+ \{\n\s*id: " + loader + r"\n", shell)
    assert m, f"{loader}: Variants not found in shell.qml"
    assert m.group(1) == "settledScreens.screens", f"{loader} is created on unsettled outputs ({m.group(1)})"
assert re.search(r"SettledScreens \{\n\s*id: settledScreens\n\s*source: Quickshell\.screens\n", shell)

print("settled-screens: ok")
h.exit(0)
