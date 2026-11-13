"""The Keys destination (Keyboard and Shortcuts tabs), offscreen with the
device fixtures (tests/lib/device_fixtures.py).

* Keyboard: the keys that switch layouts are lit on the keyboard drawing;
  holding keys in the try field lights them, letting go puts them out; a
  switch chip relights the drawing.
* Shortcuts: opening a shortcut in the list lights its keys on the band
  and names what it does.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("settings-keys", devices=True)
h = env.h
failures: list[str] = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1180; height: 780; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && kids.indexOf(item.contentItem) === -1) kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function page() { var host = findItem("settingsPage"); return host ? host.item : null }
    function find(name) { return findItem(name, page()) }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")
win.requestActivate()
QTest.qWaitForWindowActive(win, 3000)


def ev(expr):
    return h.eval(win, expr)


def lit():
    return sorted(set(json.loads(h.eval(ev('w.find("keyboardDeck")'), "JSON.stringify(lit)"))))


h.eval(shell, 'select("keyboard")')
check(env.wait_page(win), "keyboard: page built")
QTest.qWait(250)
check(lit() == ["ALT", "SHIFT"], f"Alt+Shift switches layouts: lit on the drawing ({lit()})")
check(ev('w.find("keycap:ALT").on') is True, "...the caps themselves light")
field = ev('w.find("tryField")')
h.eval(field, "keyDown(Qt.Key_Control, '', 0)")
h.eval(field, "keyDown(Qt.Key_C, 'c', 0)")
check("CTRL" in lit() and "c" in lit(), f"keys held in the try field light up ({lit()})")
h.eval(field, "keyUp(Qt.Key_C, 'c', 0)")
h.eval(field, "keyUp(Qt.Key_Control, '', 0)")
check(lit() == ["ALT", "SHIFT"], "letting go puts them out")
h.eval(ev('w.find("bindChips")'), "selected('super_space')")
QTest.qWait(50)
check(lit() == ["SUPER", "space"], f"another switch relights the drawing ({lit()})")

h.eval(shell, 'select("input")')
check(env.wait_page(win), "shortcuts: page built")
QTest.qWait(250)
ev('KeybindsStore.expandedUid = "core:launcher"')
QTest.qWait(50)
deck = ev('w.find("keysDeck")')
row = ev("JSON.stringify(KeybindsStore.row('core:launcher').keys[0])")
shown = h.eval(deck, "JSON.stringify(lit)")
opened = shown
check(shown not in ("[]", ""), f"opening a shortcut lights its keys ({shown} for {row})")
check(ev('w.find("keysAction").text') != "", "...and the band says what it does")
# a recorder's keys light while they are pressed, before the combo is saved
ev('KeybindsStore.recordingDraft = {"modifiers": ["SUPER", "SHIFT"], "key": ""}')
QTest.qWait(50)
shown = sorted(json.loads(h.eval(deck, "JSON.stringify(lit)")))
check(shown == ["SHIFT", "SUPER"], f"held modifiers light while recording ({shown})")
check(ev('w.find("keysCombo").text').endswith("…"), "...the combo so far waits for its key")
ev("KeybindsStore.recordingDraft = null")
QTest.qWait(50)
check(h.eval(deck, "JSON.stringify(lit)") == opened, "...and the opened shortcut's keys come back after")

if failures:
    print(f"settings-keys: {len(failures)} failure(s)")
    h.exit(1)
print("settings-keys: ok")
h.exit(0)
