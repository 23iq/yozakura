"""Presets > Changes as a list page, offscreen: the band counts what differs
and puts it all back as one undo step; a row resets one setting.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("settings-changes-page")
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
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr):
    return h.eval(win, expr)


ev("SettingsStore.set('bar.compact', true)")
ev("SettingsStore.set('voice.language', 'es')")
QTest.qWait(1700)  # past the merge window: separate steps
h.eval(shell, 'select("changes")')
QTest.qWait(400)
check(ev('w.findItem("changesBand") !== null'), "changes: the band")
check(ev('w.findItem("changesList") !== null'), "changes: the list in its card")
rows = ev("""(function() {
    var n = 0;
    function walk(it) {
        if (String(it.objectName).indexOf("changeRow:") === 0 && it.visible) n++;
        var kids = it.children || [];
        if (it.contentItem && it.contentItem !== it && kids.indexOf(it.contentItem) === -1) kids = kids.concat([it.contentItem]);
        for (var i = 0; i < kids.length; i++) walk(kids[i]);
    }
    walk(w.findItem("changesList"));
    return n;
})()""")
check(rows >= 2, f"changes: a row per changed setting ({rows})")
n = ev("SettingsStore.undoStack.length")
h.eval(ev('w.findItem("changesResetAll")'), "clicked()")
QTest.qWait(100)
check(ev("Config.bar.compact") is False and ev("Config.voice.language") == "auto", "changes: put all back")
check(ev("SettingsStore.undoStack.length") == n + 1, "changes: one undo step")
ev("SettingsStore.undo()")
check(ev("Config.bar.compact") is True and ev("Config.voice.language") == "es", "changes: one undo brings them all")
ev("SettingsStore.set('bar.compact', false)")
ev("SettingsStore.set('voice.language', 'auto')")

if failures:
    print(f"settings-changes-page: {len(failures)} failure(s)")
    h.exit(1)
print("settings-changes-page: ok")
h.exit(0)
