"""The lock screen style gallery finishes its pictures after the window was
hidden mid-way, offscreen.

LockStyleGallery pictures one live LockView at a time (grabToImage). A hidden
window refuses the capture; the gallery used to stop for good then (4 of 6
cards empty on every later open, one LockView kept alive). Now the picture in
progress pauses and is taken again once the window shows.
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

env = SettingsEnv("lock-gallery-resume")
h = env.h
win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings
Window {
    id: w
    width: 1180; height: 780; visible: true
    // [pictured, cards, live views]
    function counts() {
        var n = 0, total = 0, live = 0;
        (function walk(it) {
            if (String(it.objectName).indexOf("lockPreview:") === 0) { total++; if (it.grabbed) n++; if (it.live) live++; }
            for (var i = 0; i < it.children.length; i++) walk(it.children[i]);
        })(w.contentItem);
        return [n, total, live];
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")
QTest.qWaitForWindowActive(win, 3000)
h.eval(shell, 'select("lockscreen")')
ok = env.wait_page(win)
QTest.qWait(1200)
win.hide()
QTest.qWait(3000)
win.show()
QTest.qWaitForWindowExposed(win, 3000)


def counts():
    return [int(x) for x in str(h.eval(win, "counts().join(',')")).split(",")]


done = wait_until(lambda: counts()[1] > 0 and counts()[0] == counts()[1], timeout_ms=20000)
n, total, live = counts()
failures = []
if not ok:
    failures.append("the Lock screen page was not built")
if not done:
    failures.append(f"every style is pictured after the window shows again ({n}/{total})")
if live > 1:
    failures.append(f"at most one live lock view ({live})")
for f in failures:
    print("FAIL:", f, file=sys.stderr)
h.exit(1 if failures else 0)
