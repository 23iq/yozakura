"""Settings pages build without layout loops, offscreen.

Regression: the kit Dropdown derived its implicitWidth from its Row, whose
label width follows the Dropdown's own width. Inside a settings row
(Notifications > corner position, a selector long enough for a dropdown)
that was a polish loop: ~50 "possible QQuickItem::polish() loop" warnings
and a ~650 ms page build in this harness, a long freeze of the live shell.

Checks: every category page loads at the settings window sizes with no
polish or binding loop, and a Dropdown's implicitWidth does not follow its
width.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("settings-layout-loops")
h = env.h

loops: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    if "polish() loop" in msg or "polish() inside updatePolish()" in msg or "Binding loop" in msg:
        loops.append(msg)
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
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.components.kit
Window {
    width: 1180; height: 780; visible: true
    SettingsShell { objectName: "shell"; anchors.fill: parent }
    Dropdown {
        objectName: "dropdown"
        y: -200
        options: [{"value": 1, "text": "One"}, {"value": 2, "text": "A much longer option label"}]
        value: 2
    }
}""")
shell = h.find(win, "shell")

# The Dropdown's natural width is its content's, whatever width it is given.
dropdown = h.find(win, "dropdown")
natural = h.eval(dropdown, "implicitWidth")
h.eval(dropdown, "width = 640")
QTest.qWait(50)
check(abs(h.eval(dropdown, "implicitWidth") - natural) < 0.5, "Dropdown implicitWidth does not follow width")
h.eval(dropdown, "width = 120")
QTest.qWait(50)
check(abs(h.eval(dropdown, "implicitWidth") - natural) < 0.5, "Dropdown implicitWidth does not follow a narrow width")

categories = ["appearance", "wallpapers", "layout", "bar", "notch", "dashboard", "launcher", "dock", "overview",
              "sidebar", "menus", "osd", "context", "surfaces", "glass", "motion", "icons-type", "desktop",
              "lockscreen", "notifications", "specials", "windows", "terminal", "input", "system", "voice", "timers",
              "routines", "updates", "ai", "ai-providers", "ai-code", "presets", "displays", "keyboard", "extras",
              "about"]

# The loop showed at the default window size (1180x780) and 1100x760.
for w, ht in ((1180, 780), (1100, 760), (900, 700)):
    win.setWidth(w)
    win.setHeight(ht)
    for cat in categories:
        before = len(loops)
        h.eval(shell, f'select("{cat}")')
        QTest.qWait(120)
        check(len(loops) == before, f"{cat} at {w}x{ht}: layout loop\n  " + "\n  ".join(loops[before:before + 3]))

# Notifications > corner position shows the dropdown: no loop when visible.
h.eval(shell, 'select("notifications")')
h.eval(shell, "SettingsStore.set('notifications.presentation', 'corner')")
QTest.qWait(300)
check(not loops, "notifications with the position dropdown shown: layout loop\n  " + "\n  ".join(loops[:3]))
print("ok")
