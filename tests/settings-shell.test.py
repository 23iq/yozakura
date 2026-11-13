"""The settings window shell (modules/settings), offscreen.

* Live changes and undo: a row writes Config at once (nothing staged, no
  preview relay), the undo pill names the change, Ctrl+Z / the pill undo it,
  Ctrl+Shift+Z redoes it; a slider drag is one step; Reset page is one step.
* Navigation: home tiles open their destination (the first tab), the tabs
  inside a destination, Esc / back pill / Alt+Left return home, old ids
  still open their page.
* Pages: kept alive (a revisit is the same page, the oldest beyond the
  bound is destroyed), out-of-window entries have no row, a section with
  no row to show has no header (R1), a waiting row offers its switch
  instead of a grey dead end, the home search finds window rows only,
  names their destination and lands on the row with focus and a flash.
* Stage: the page's miniature is built; a hovered row lights its part; a
  click on an edge of the tiny screen moves the bar (one undo step), a
  click on the island opens its tab, a click on a corner moves the
  notifications.
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
check(ev('w.findItem("destinationTitle").text') == "Desktop layout", "the destination title")
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

# direct manipulation: an edge of the tiny screen moves the bar
edges = ev('w.findItem("barEdgePicker", w.findItem("settingsPage").item)')
check(edges is not None, "the Bar stage has edge targets")
h.eval(edges, 'preview = "left"')
QTest.qWait(30)
check(h.eval(edges, "hovered") == "left", "a hovered edge shows its ghost")
h.eval(edges, 'preview = ""')
h.eval(edges, 'picked("left")')
check(ev("Config.bar.position") == "left", "a click on the left edge moves the bar there")
check(ev('w.findItem("undoText").text') == "Bar moved", "...as one named undo step")
ev("SettingsStore.undo()")
check(ev("Config.bar.position") == "top", "and one undo puts it back")
# one explicit panel: its edge moves (bar.position is ignored then)
ONE = '[{id: "only", edge: "top", style: "classic", groups: {start: ["launcher"], end: ["clock"]}}]'
ev(f"SettingsStore.set('bar.panels', {ONE})")
QTest.qWait(80)
steps = ev("SettingsStore.undoStack.length")
h.eval(edges, 'picked("bottom")')
check(ev("Config.bar.panels[0].edge") == "bottom", "with one explicit panel the click moves that panel")
check(ev("SettingsStore.undoStack.length") == steps + 1, "...as one undo step")
ev("SettingsStore.undo()")
check(ev("Config.bar.panels[0].edge") == "top", "and undo puts it back")
ev("SettingsStore.set('bar.panels', [])")
QTest.qWait(80)
part = ev('w.findItem("stagePart:island", w.findItem("settingsPage").item)')
check(part is not None, "the island on the Bar stage is a button")
h.eval(part, "clicked(null)")
check(env.wait_page(win) and sev("currentCategory") == "notch", "a click on the island opens the Island tab")
select("notifications")
ev("SettingsStore.set('notifications.presentation', 'corner')")
QTest.qWait(50)
corner = ev('w.findItem("notifPlace:bottom-left", w.findItem("settingsPage").item)')
check(corner is not None and h.eval(corner, "visible") is True, "with corner toasts every other corner is a target")
h.eval(ev("w.findItem(\"notifPlaceArea:bottom-left\", w.findItem(\"settingsPage\").item)"), "clicked(null)")
check(ev("Config.notifications.position") == "bottom-left", "a click on a corner moves the notifications there")
ev("SettingsStore.undo()")
ev("SettingsStore.set('notifications.presentation', 'auto')")
select("bar")

# several bars: the stage draws them all; a click on one picks it for the editor
PANELS = ('[{id: "top", edge: "top", style: "classic", groups: {start: ["launcher"], end: ["clock"]}},'
          ' {id: "rail", edge: "left", style: "rail", groups: {start: ["launcher"], end: ["power"]}}]')
ev(f"SettingsStore.set('bar.panels', {PANELS})")
QTest.qWait(150)
mini = ev("""(function() {
    var found = null;
    (function walk(it) { if (!found && it.panelPicked !== undefined) found = it; for (var i = 0; i < it.children.length; i++) walk(it.children[i]); })(w.findItem("pageStage", w.findItem("settingsPage").item));
    return found;
})()""")
check(mini is not None and h.eval(mini, "sketches.length") == 2, "the stage draws every bar")
check(h.eval(mini, "depths.left") > 0 and h.eval(mini, "freeRect.x") >= h.eval(mini, "depths.left"),
      "the rail's reserved space is left free")
h.eval(mini, "panelPicked(1)")
check(ev("SettingsStore.selectedPanel") == 1, "a click on the rail picks it")
QTest.qWait(100)
# the bars editor is in the More sheet, built on first open
ev('w.findItem("settingsPage").item.moreBuilt = true')
QTest.qWait(50)
editor = ev('w.findItem("settingRow:bar.panels.editor")')
check(editor is not None and h.eval(editor, "shown") is True, "the bars editor shows while several bars are set")
ev("SettingsStore.set('bar.panels', [])")
ev("SettingsStore.selectedPanel = 0")

# ---- navigation, tabs, keep-alive ---------------------------------------------
tabs = ev('w.findItem("destinationTabs")')
check(tabs is not None and h.eval(tabs, "count") == 4, "Desktop layout has four tabs")
bar_page = ev('w.findItem("settingsPage").item')
h.eval(tabs, "activated(1)")
check(env.wait_page(win) and sev("currentCategory") == "notch", "a tab opens its page")
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
for old in ("popups", "surfaces", "island", "input"):
    sev(f'select("{old}")')
    check(sev("currentCategory") != "", f"old id {old} still opens a page")

# home: back and a tile
QTest.keyClick(win, Qt.Key_Left, Qt.AltModifier)
check(sev("atHome") is True, "Alt+Left returns home")
tile = ev('w.findItem("homeTile:look")')
check(tile is not None, "home has a Look tile")
check(wait_until(lambda: sev("reveal") == 0), "home fully shown")
h.eval(tile, "clicked()")
check(env.wait_page(win) and sev("currentCategory") == "appearance" and sev("atHome") is False, "a tile opens its first tab")
h.eval(ev('w.findItem("backPill")'), "clicked()")
check(sev("atHome") is True, "the back pill returns home")
check(wait_until(lambda: sev("reveal") == 0), "home shown again")

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

# ---- a multi-key editor is one undo step --------------------------------------
select("appearance")
modes = ev('w.findItem("themeModeCards", w.findItem("settingsPage").item)')
check(modes is not None, "the Mode editor is on the Look page")
h.eval(modes, 'choose("light")')
QTest.qWait(1700)  # past the merge window: two steps
h.eval(modes, 'choose("oled")')
check(ev("Config.theme.lightMode") is False and ev("Config.theme.oledMode") is True, "OLED picked")
ev("SettingsStore.undo()")
check(ev("Config.theme.lightMode") is True, "one undo goes back to Light (not dark non-OLED)")
ev("SettingsStore.undo()")
check(ev("Config.theme.lightMode") is False and ev("Config.theme.oledMode") is False, "and one more to where it started")

# ---- search ---------------------------------------------------------------------
sev("openSearch()")
field = ev('w.findItem("settingsSearch")')
h.eval(field, 'text = "reveal strip"')
QTest.qWait(50)
check(ev('w.findItem("settingsHome").results.length') == 0, "search finds no out-of-window entry")
h.eval(field, 'text = "clock face"')
QTest.qWait(50)
check(ev('w.findItem("settingsHome").results[0].entryId') == "bar.moduleOptions.clock.face", "search finds the row")
check("Desktop layout" in ev('w.findItem("settingsHome").results[0].context'), "results name the destination")
ev('w.findItem("settingsHome").activateResult(0)')
check(wait_until(lambda: ev("SettingsStore.highlightedEntry") == "bar.moduleOptions.clock.face"), "the jump flashes the row")
check(ev('w.findItem("settingRow:bar.moduleOptions.clock.face").activeFocus') is True, "...and gives it focus")
h.eval(field, 'text = ""')

if failures:
    print(f"settings-shell: {len(failures)} failure(s)")
    h.exit(1)
print("settings-shell: ok")
h.exit(0)
