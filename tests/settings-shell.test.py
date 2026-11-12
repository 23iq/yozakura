"""The settings window shell (modules/settings), offscreen.

* Live changes and undo: a row writes Config at once (nothing staged, no
  preview relay), the undo pill names the change, Ctrl+Z / the pill undo it,
  Ctrl+Shift+Z redoes it; a slider drag is one step; Reset page is one step.
* Navigation: the flat sidebar of destinations, tabs inside a destination,
  old ids still open their page.
* Pages: kept alive (a revisit is the same page, the oldest beyond the
  bound is destroyed), out-of-window entries have no row, a section with
  no row to show has no header (R1), a waiting row offers its switch
  instead of a grey dead end, search finds window rows only and lands on
  the row with focus and a flash.
* Stage: the page's miniature is built; a hovered row lights its part.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402
from waits import wait_until  # noqa: E402

env = SettingsEnv("settings-shell")
h = env.h
failures: list[str] = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1180; height: 780; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")
win.requestActivate()
QTest.qWaitForWindowActive(win, 3000)


def ev(expr):
    return h.eval(win, expr)


def sev(expr):
    return h.eval(shell, expr)


def select(cat):
    sev(f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")


# ---- live changes + undo ----------------------------------------------------
select("bar")
check(ev('w.findItem("destinationTitle").text') == "Bar", "the destination title")
ev("BackendService.calls = []")
ev("SettingsStore.set('bar.compact', true)")
check(ev("Config.bar.compact") is True, "a change applies at once")
check(ev("GlobalStates.shellHasChanges") is False and ev("SettingsStore.hasChanges") is False, "nothing is staged")
check(ev("BackendService.calls.indexOf('preview.set')") == -1, "a live change is not relayed: the file carries it")
pill = ev('w.findItem("undoPill")')
check(wait_until(lambda: h.eval(pill, "shown") is True), "the undo pill appears after a change")
said = ev('w.findItem("undoText").text')
check(said == "Compact changed", f"the pill names the change: {said!r}")
QTest.keyClick(win, Qt.Key_Z, Qt.ControlModifier)
check(ev("Config.bar.compact") is False, "Ctrl+Z undoes it")
check(ev('w.findItem("undoAction").text') == "Redo", "after an undo the pill offers Redo")
QTest.keyClick(win, Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
check(ev("Config.bar.compact") is True, "Ctrl+Shift+Z redoes it")
h.eval(ev('w.findItem("undoAction")'), "clicked()")
check(ev("Config.bar.compact") is False, "the pill's Undo undoes it")

# a drag: many values of one setting in a burst are one step
n0 = ev("SettingsStore.undoStack.length")
for v in range(2, 9):
    ev(f"SettingsStore.set('workspaces.shown', {v})")
check(ev("SettingsStore.undoStack.length") == n0 + 1, "a burst of one setting is one undo step")
ev("SettingsStore.undo()")
check(ev("Config.workspaces.shown") == 10, "and one undo returns to where it started")

# Reset page: one step, back with one undo
ev("SettingsStore.set('bar.compact', true)")
ev("SettingsStore.set('bar.clockShowDate', true)")
QTest.qWait(50)
reset = ev('w.findItem("pageReset")')
check(h.eval(reset, "visible") is True, "Reset page shows while the page differs from its defaults")
h.eval(reset, "triggered()")
check(ev("Config.bar.compact") is False and ev("Config.bar.clockShowDate") is False, "Reset page resets the page")
check(ev('w.findItem("undoText").text') == "Page reset", ev('w.findItem("undoText").text'))
ev("SettingsStore.undo()")
check(ev("Config.bar.compact") is True and ev("Config.bar.clockShowDate") is True, "one undo brings the whole page back")
ev("SettingsStore.set('bar.compact', false); SettingsStore.set('bar.clockShowDate', false)")

# a row's reset is shown only while it differs
row = ev('w.findItem("settingRow:bar.compact")')
check(ev('w.findItem("rowReset", w.findItem("settingRow:bar.compact"))') is None, "no reset on a default row")
ev("SettingsStore.set('bar.compact', true)")
QTest.qWait(30)
check(ev('w.findItem("rowReset", w.findItem("settingRow:bar.compact"))') is not None, "a modified row offers its reset")
ev("SettingsStore.set('bar.compact', false)")

# ---- the stage ---------------------------------------------------------------
check(ev('w.findItem("pageStage", w.findItem("settingsPage").item).item') is not None, "the Bar page has its stage")
styleRow = ev('w.findItem("settingRow:bar.layout.style")')
p = h.eval(styleRow, "mapToItem(null, 40, 20)")
QTest.mouseMove(win, QPoint(int(p.x()), int(p.y())))
QTest.qWait(80)
check(ev("SettingsStore.focusKeys.indexOf('bar.layout.style') >= 0"), "hovering a row tells the stage its keys")
lit = ev("""(function() {
    var n = 0;
    (function walk(it) { if (it.lit === true) n++; for (var i = 0; i < it.children.length; i++) walk(it.children[i]); })(w.findItem("pageStage", w.findItem("settingsPage").item));
    return n;
})()""")
check(lit > 0, f"...and the stage lights the bar ({lit} parts)")
QTest.mouseMove(win, QPoint(4, 4))
QTest.qWait(80)
check(ev("SettingsStore.focusKeys.length") == 0, "leaving the row clears it")

# ---- navigation, tabs, keep-alive ---------------------------------------------
tabs = ev('w.findItem("destinationTabs")')
check(tabs is not None and h.eval(tabs, "count") == 2, "Bar has two tabs")
bar_page = ev('w.findItem("settingsPage").item')
h.eval(tabs, "activated(1)")
check(env.wait_page(win) and sev("currentCategory") == "layout", "a tab opens its page")
check(ev('w.findItem("settingsPage").direction') == 1, "the tab to the right slides in from the right")
select("look")
check(sev("currentCategory") == "appearance", "a destination id opens its first tab")
select("bar")
check(ev('w.findItem("settingsPage").item') == bar_page, "a revisit shows the kept page")
for cat in ("dock", "notch", "launcher", "dashboard"):
    select(cat)
select("bar")
check(ev('w.findItem("settingsPage").item') != bar_page, "past the bound the oldest page was rebuilt")
check(ev('w.findItem("settingsPage")._pages.length') <= 4, "at most four pages are kept")
for old in ("popups", "surfaces", "island"):
    sev(f'select("{old}")')
    check(sev("currentCategory") != "", f"old id {old} still opens a page")

# ---- what the window shows -----------------------------------------------------
select("bar")
check(ev('w.findItem("settingRow:bar.hoverRegionHeight")') is None, "an out-of-window entry has no row")
expert = ev('w.findItem("settingsSection:expert")')
check(expert is None or h.eval(expert, "visible") is False, "an out-of-window section shows nothing")
# R1: a section whose every row is hidden has no header
select("overview")
sec = ev('w.findItem("settingsSection:wallpaper")')
check(sec is None or h.eval(sec, "visible") is False, "a section with no row to show has no header (Overview on Hyprland)")
# no grey dead end: a row waiting for one switch offers it
select("notch")
ev("SettingsStore.set('notch.disableHoverExpansion', true)")
QTest.qWait(50)
fix = ev('w.findItem("disabledFix")')
check(fix is not None and h.eval(fix, "visible") is True, "a waiting row offers its one switch")
h.eval(fix, "clicked()")
check(ev("Config.notch.disableHoverExpansion") is False, "...which turns it on")

# ---- search ---------------------------------------------------------------------
field = ev('w.findItem("settingsSearch")')
h.eval(field, 'text = "reveal strip"')
QTest.qWait(50)
check(ev('w.findItem("settingsSidebar").results.length') == 0, "search finds no out-of-window entry")
h.eval(field, 'text = "clock face"')
QTest.qWait(50)
check(ev('w.findItem("settingsSidebar").results[0].entryId') == "bar.moduleOptions.clock.face", "search finds the row")
check("Bar" in ev('w.findItem("settingsSidebar").results[0].context'), "results name the destination")
ev('w.findItem("settingsSidebar").activateResult(0)')
check(wait_until(lambda: ev("SettingsStore.highlightedEntry") == "bar.moduleOptions.clock.face"), "the jump flashes the row")
check(ev('w.findItem("settingRow:bar.moduleOptions.clock.face").activeFocus') is True, "...and gives it focus")
h.eval(field, 'text = ""')

if failures:
    print(f"settings-shell: {len(failures)} failure(s)")
    h.exit(1)
print("settings-shell: ok")
h.exit(0)
