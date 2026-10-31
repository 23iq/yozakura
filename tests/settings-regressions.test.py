"""Settings regressions found by the runtime click-through QA, offscreen.

  * Bar -> Panels -> Add panel: the schematic redraws without TypeErrors when
    the panel list grows or shrinks (sketches lag panels for an evaluation).
  * The compact settings window (< 860 px) still has a search: the rail's
    search button and Ctrl+F open the wide sidebar, a pick closes it.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("settings-regressions")
h = env.h

errors: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "Unable to assign",
                              "failed to load")):
        errors.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


qInstallMessageHandler(_capture)


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.settings
import qs.modules.settings.previews
Window {
    id: w
    width: 700; height: 760; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    PanelsSchematic { objectName: "sch"; width: 320; panels: [] }
    SettingsShell { objectName: "shell"; x: 0; y: 400; width: 700; height: 360 }
}""")
sch = h.find(win, "sch")
shell = h.find(win, "shell")

panel = '{id: "%s", edge: "%s", style: "classic", groups: {end: ["clock"]}, align: "fill", size: 0, thickness: 0, margin: -1, flat: false, autohide: "auto", reserve: true, screens: [], enabled: true, options: {}}'
one = "[" + panel % ("a", "top") + "]"
two = "[" + panel % ("a", "top") + "," + panel % ("b", "left") + "]"
for expr in (one, two, "[]", two, one):
    h.eval(sch, f"panels = {expr}")
    QTest.qWait(60)
check(not errors, "schematic redraw errors:\n  " + "\n  ".join(errors))
check(h.eval(sch, "sketches.length") == 1, "schematic follows the panel list")

# Compact window: search stays reachable.
check(h.eval(shell, "compact") is True, "700 px is compact")
check(h.eval(shell, "railed") is True, "compact starts as the icon rail")
rail_btn = h.find(win, "railSearch")
check(rail_btn is not None and h.eval(rail_btn, "visible") is True, "rail has a search button")
h.eval(rail_btn, "clicked()")
QTest.qWait(150)
check(h.eval(shell, "searchOpen") is True and h.eval(shell, "railed") is False, "search button opens the sidebar")
field = h.find(win, "settingsSearch")
check(field is not None and h.eval(field, "visible") is True, "search field is visible when opened")
h.eval(shell, "select('bar')")
QTest.qWait(100)
check(h.eval(shell, "searchOpen") is False and h.eval(shell, "railed") is True, "picking a page closes it")
h.eval(shell, "openSearch()")
QTest.qWait(150)
check(h.eval(shell, "searchOpen") is True, "Ctrl+F path opens the search when compact")
check(not errors, "QML errors:\n  " + "\n  ".join(errors))
print("settings-regressions: ok")
