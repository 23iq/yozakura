"""Launcher looks (layout.launcher.*), offscreen: result styles (list, cards,
grid with 2D keyboard navigation and the list fallback), the lazy preview
pane and compactWhenEmpty."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from launcher_env import LauncherEnv  # noqa: E402

from PySide6.QtTest import QTest  # noqa: E402

env = LauncherEnv("launcher-styles")
h = env.h
win = env.load("""
import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.launcher
Window {
    width: 960; height: 440; visible: true; color: "black"
    LauncherView { objectName: "view"; width: implicitWidth; height: implicitHeight }
}""")
view = h.find(win, "view")
search = h.find(win, "launcherSearch")
results = h.find(win, "launcherResults")
grid = h.find(win, "launcherGrid")
preview = h.find(win, "launcherPreview")
fails: list[str] = []


def check(cond, msg):
    if not cond:
        fails.append(msg)
        print("FAIL:", msg, file=sys.stderr)


def settle(ms=700):
    QTest.qWait(ms)


def type_text(t):
    h.eval(view, f"GlobalStates.launcherSearchText = {json.dumps(t)}")
    settle(80)


def type_fast(t):
    h.eval(view, f"GlobalStates.launcherSearchText = {json.dumps(t)}")


def layout(**kw):
    h.eval(view, f"Config.layout.launcher = Object.assign({{}}, Config.layout.launcher, {json.dumps(kw)})")
    settle(80)


def sv(expr):
    return h.eval(search, "(function(v){ return " + expr + " })(this)")


settle(300)

# list: today's look
type_text("")
check(sv("v.styleName") == "list" and h.eval(results, "style") == "list", "default style is list")
check(h.eval(results, "rowHeight") == 48, "list row is Metrics.rowHeight")

# cards: 1.5x rows
layout(resultStyle="cards", preview=False)
check(h.eval(results, "style") == "cards" and h.eval(results, "rowHeight") == 72, "cards style, row 72")
check(h.eval(results, "visible") and not h.eval(grid, "visible"), "cards use the list view")

# grid: apps only, keyboard moves in 2D
layout(resultStyle="grid")
type_text("")
check(sv("v.gridActive") and h.eval(grid, "visible"), "grid active for the app list")
cols = h.eval(grid, "columns")
check(cols >= 3, f"grid has columns: {cols}")
sv("v.select(0)")
sv("v.gridKey('right')")
check(sv("v.selectedIndex") == 1, "right moves to the next cell")
sv("v.gridKey('down')")
check(sv("v.selectedIndex") == 1 + cols, f"down moves one row ({cols} columns)")
sv("v.gridKey('left')")
check(sv("v.selectedIndex") == cols, "left moves back")
sv("v.gridKey('up')")
check(sv("v.selectedIndex") == 0, "up moves a row up")
sv("v.gridKey('up')")
check(sv("v.selectedIndex") == 0, "up on the first row stays")
# Arrow keys from the search field reach the grid.
sv("v.select(0)")
h.eval(h.find(win, "launcherSearchInput"), "rightPressed()")
check(sv("v.selectedIndex") == 1, "search field right arrow drives the grid")

# Non-app results fall back to the list.
type_text("12*7")
check(sv("v.styleName") == "list" and not h.eval(grid, "visible"), "grid falls back to list for non-app results")
layout(resultStyle="list")

# preview: opens for a calculator result, loads lazily, can be turned off
type_text("")
layout(preview=True)
settle(300)
type_fast("12*7")
check(sv("v.previewOpen"), "preview open for the calculator result")
check(h.eval(preview, "shown") is None or h.eval(preview, "shown") == {}, "preview content waits for the pause")
settle()
check(h.eval(preview, "shown.title") == "= 84", "preview shows the settled result")
check(h.eval(view, "implicitWidth") == h.eval(view, "Metrics.launcherWideW"), "view widens for the preview")
type_fast("5 kg in lb")
check(h.eval(preview, "shown.title") == "= 84", "preview lags behind fast typing (never blocks)")
settle(300)
check(h.eval(preview, "shown.title").startswith("= 11.02"), "preview follows once typing pauses")
type_text("fire")
settle(300)
check(sv("v.previewOpen"), "apps get the detail pane")
check(h.eval(view, "implicitHeight") == h.eval(view, "Metrics.launcherWideH"), "view grows for the detail pane")
check(h.eval(preview, "shown.title") == "Firefox", "detail shows the selected app")
check(h.eval(preview, "actions.length") == 3 and h.eval(preview, "actions[0].id") == "", "detail lists the app actions, main first")
h.eval(preview, "actionTriggered('')")
check(h.eval(view, "Visibilities.module") == "", "a detail action runs the result and closes")
h.eval(view, "Visibilities.module = 'launcher'")
type_text("=")
check(not sv("v.previewOpen"), "no detail for hint rows")
layout(preview=False)
type_text("12*7")
check(not sv("v.previewOpen"), "preview off")
layout(preview=True)

# file preview kinds
h.eval(preview, "selection = {provider: 'files', title: 'a.md', subtitle: '~', data: {path: '/tmp/a.md'}}")
settle(300)
check(h.eval(preview, "available"), "files have a preview")
check(h.eval(preview, "shown.title") == "a.md", "file preview settled")

# grouped list + field hints
layout(preview=False)
type_text("")
field = h.find(win, "launcherSearchInput")
check(h.eval(field, "hints.join(' ')") == "cc ee = ?", "prefix hints at the right of the field")
type_text("fi")
check(h.eval(results, "groups.starts[0]") is True, "the first result opens a section")
check(h.eval(results, "rowY(0)") == h.eval(results, "labelHeight"), "rows sit below their section label")

# compactWhenEmpty: only the search field until the first keystroke
layout(compactWhenEmpty=True)
type_text("")
settle()
check(h.eval(view, "bare") and h.eval(view, "implicitHeight") == h.eval(view, "Metrics.rowHeight"), "empty search shrinks to the field")
check(h.eval(view, "height") == h.eval(view, "Metrics.rowHeight"), "view follows (morphed) to the field height")
type_text("fire")
settle()
check(not h.eval(view, "bare") and h.eval(view, "height") == h.eval(view, "Metrics.launcherCompactH"), "first keystroke opens the launcher")
layout(compactWhenEmpty=False, preview=True)

if fails:
    print(f"{len(fails)} failure(s)", file=sys.stderr)
    h.exit(1)
print("launcher-styles: ok")
h.exit(0)
