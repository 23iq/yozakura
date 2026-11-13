"""The settings window's undo history in SettingsStore, offscreen.

* The undo pill acts on the step it names: a change taken back within the
  coalescing window (a switch flipped twice) leaves nothing to offer, the
  pill hides, and its button never undoes an older, unrelated step; a stale
  id is refused.
* An undo (or redo) whose key no longer holds the value it set (changed by
  another process, `config set`, a preset) is dropped, never written.
* A reload of a domain that changed a value the history expects clears the
  history; our own write coming back keeps it. Closing the window clears it.
* A macro slider (several keys per point) dragged over its points is one
  undo step.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402
from waits import wait_until  # noqa: E402

failures: list[str] = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


env = SettingsEnv("settings-undo-store")
# The real Config announces a reloaded domain (config/Config.qml).
cfg = env.root / "qs" / "config" / "Config.qml"
cfg.write_text(cfg.read_text().replace("    property var saved: []", "    property var saved: []\n    signal domainReloaded(string name)", 1))
h = env.h

win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.globals
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 600; height: 200; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    UndoPill { objectName: "pill"; y: 100 }
}""")


def ev(expr):
    return h.eval(win, expr)


pill = h.find(win, "pill")
action = ev('w.findItem("undoAction")')
COALESCE = 1700  # UndoModel.COALESCE_MS + margin


def settle():
    QTest.qWait(COALESCE)


# ---- the pill names the step it undoes --------------------------------------
ev("SettingsStore.set('bar.position', 'left')")
settle()
ev("SettingsStore.set('bar.compact', true)")
QTest.qWait(50)
check(h.eval(pill, "shown") is True and ev('w.findItem("undoText").text') == "Compact changed", "the pill names the change")
ev("SettingsStore.set('bar.compact', false)")  # flipped back at once
QTest.qWait(50)
check(ev("SettingsStore.lastStep") is None, "a change taken back announces nothing")
check(wait_until(lambda: h.eval(pill, "shown") is False), "...and the pill that named it hides")
h.eval(action, "clicked()")
check(ev("Config.bar.position") == "left", "its button does not undo an older, unrelated step")
check(ev("SettingsStore.undoStack.length") == 1, "the older step is still there")

ev("SettingsStore.set('bar.clockShowDate', true)")
QTest.qWait(50)
shown_id = ev("SettingsStore.lastStep.id")
check(ev("SettingsStore.undoStep(%d - 1)" % shown_id) is False, "undoStep refuses an id that is not the newest step")
check(ev("Config.bar.clockShowDate") is True, "...and writes nothing")
use12 = ev("Config.bar.use12hFormat")
ev(f"SettingsStore.set('bar.use12hFormat', {str(not use12).lower()})")
QTest.qWait(50)
h.eval(action, "clicked()")
check(ev("Config.bar.use12hFormat") is use12 and ev("Config.bar.clockShowDate") is True
      and ev("Config.bar.position") == "left", "the pill undoes the step it names")
check(ev('w.findItem("undoAction").text') == "Redo", "...and offers Redo")
h.eval(action, "clicked()")
check(ev("Config.bar.use12hFormat") is (not use12), "...which redoes that step")
ev("SettingsStore.clearHistory()")
ev(f"SettingsStore.set('bar.use12hFormat', {str(use12).lower()})")
ev("SettingsStore.set('bar.clockShowDate', false); SettingsStore.set('bar.position', 'top')")
ev("SettingsStore.clearHistory()")

# ---- an undo never writes a stale value --------------------------------------
ev("SettingsStore.set('workspaces.shown', 5)")
settle()
ev("Config.workspaces.shown = 7")  # what a reload from disk does
check(ev("SettingsStore.undo()") is False, "an undo whose key changed elsewhere is refused")
check(ev("Config.workspaces.shown") == 7, "...the value from elsewhere stays")
check(ev("SettingsStore.undoStack.length") == 0 and ev("SettingsStore.redoStack.length") == 0, "...and the step is dropped")

ev("SettingsStore.set('workspaces.shown', 6)")
ev("SettingsStore.undo()")
check(ev("Config.workspaces.shown") == 7, "a fresh step undoes as usual")
ev("Config.workspaces.shown = 3")
check(ev("SettingsStore.redo()") is False and ev("Config.workspaces.shown") == 3, "a stale redo is refused too")
ev("Config.workspaces.shown = 10; SettingsStore.clearHistory()")

# ---- reloads and closing the window ------------------------------------------
ev("SettingsStore.set('dock.position', 'left')")
settle()
ev("Config.domainReloaded('dock')")  # our own write coming back: same values
check(ev("SettingsStore.undoStack.length") == 1, "a reload that changed nothing keeps the history")
ev("Config.bar.compact = true; Config.domainReloaded('bar')")
check(ev("SettingsStore.undoStack.length") == 1, "a reload of a key the history never touched keeps it")
ev("Config.bar.compact = false")
ev("Config.dock.position = 'right'; Config.domainReloaded('dock')")
check(ev("SettingsStore.undoStack.length") == 0 and ev("SettingsStore.lastStep") is None,
      "a reload that changed a value the history expects clears it")
ev("Config.dock.position = 'bottom'")
ev("SettingsStore.set('dock.position', 'left')")
ev("GlobalStates.settingsWindowVisible = false")
check(ev("SettingsStore.undoStack.length") == 0, "closing the window clears the history")
ev("GlobalStates.settingsWindowVisible = true")
ev("Config.dock.position = 'bottom'")

# ---- a macro slider drag is one step -----------------------------------------
n0 = ev("SettingsStore.undoStack.length")
for r, corners in ((8, True), (12, True), (16, False), (20, True)):
    ev(f"SettingsStore.transaction('prefs.macro.roundness', () => {{ SettingsStore.set('theme.roundness', {r}); "
       f"SettingsStore.set('theme.enableCorners', {str(corners).lower()}) }})")
    QTest.qWait(40)
check(ev("SettingsStore.undoStack.length") == n0 + 1, "a macro drag over four points is one undo step")

if failures:
    print(f"settings-undo-store: {len(failures)} failure(s)")
    h.exit(1)
print("settings-undo-store: ok")
h.exit(0)
