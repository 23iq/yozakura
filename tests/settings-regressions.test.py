"""Settings regressions found by the runtime click-through QA, offscreen.

  * Bar -> Panels -> Add panel: the schematic redraws without TypeErrors when
    the panel list grows or shrinks (sketches lag panels for an evaluation).
  * A narrow settings window (700 px) still has its search: home shows the
    field, the Ctrl+F path (openSearch) returns home from a page and focuses
    it, a result opens its page.
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

# Narrow window: search stays reachable.
win.requestActivate()
QTest.qWaitForWindowActive(win, 3000)
h.eval(shell, "goHome()")  # the harness opens on a page (settingsCategory)
QTest.qWait(400)
field = h.find(win, "settingsSearch")
check(field is not None and h.eval(field, "visible") is True, "home shows the search field")
check(h.eval(shell, "home.columns") < 6, "a 700 px home has fewer columns")
h.eval(shell, "select('bar')")
QTest.qWait(100)
check(h.eval(shell, "atHome") is False, "a page opens")
h.eval(shell, "openSearch()")
QTest.qWait(150)
check(h.eval(shell, "atHome") is True and h.eval(field, "field.activeFocus") is True, "Ctrl+F path returns home and focuses the search")
h.eval(field, 'text = "clock face"')
QTest.qWait(50)
h.eval(shell, "home.activateResult(0)")
check(env.wait_page(win) and h.eval(shell, "currentCategory") == "bar", "a result opens its page")
h.eval(field, 'text = ""')

# Service-backed pages build offscreen with the harness stubs (no QML errors).
for cat in ("keyboard", "displays", "mods", "terminal", "extras", "system", "about"):
    h.eval(shell, f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")
    QTest.qWait(200)
check(not errors, "QML errors:\n  " + "\n  ".join(errors))
print("settings-regressions: ok")
# no interpreter teardown: kept-alive pages would outlive the singletons
env.h.exit(0)
