"""OsdSlide (the OSD's enter/exit motion, on Animators) in a real window
(GL, private Xvfb): it fades and slides in from its edge while shown, out
when hidden, reports `moving` from the moment it is hidden until the exit
motion ends (the OSD window stays up meanwhile), and with animations off
it switches at once."""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib import headless  # noqa: E402

headless.ensure(gl=True)
from lib.qmlharness import REPO, Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()
        time.sleep(0.002)


h = Harness("osd-slide")
h.module("qs.modules.shell.osd", {
    "OsdMotion": """pragma Singleton
QtObject { property int enterMs: 200; property int exitMs: 200; property int enterEasing: Easing.OutCubic; property int exitEasing: Easing.InCubic }""",
    "OsdSlide": (REPO / "modules/shell/osd/OsdSlide.qml").read_text(),
})
root = h.load("""import QtQuick
import qs.modules.shell.osd
Item {
    width: 200; height: 100
    property alias slider: s
    property var samples: []
    Item {
        x: 50; y: 20; width: 100; height: 40
        OsdSlide { id: s; slide: Qt.point(0, 1); Rectangle { anchors.fill: parent; color: "red" } }
    }
}""", auto_stub=False)

win = QQuickWindow()
win.resize(200, 100)
root.setParentItem(win.contentItem())
win.show()
pump(100)


def ev(expr):
    return h.eval(root, expr)


check("hidden at rest: transparent, offset by its distance from the edge",
      ev("slider.opacity") == 0 and ev("slider.y") == 14 and not ev("slider.moving"))

ev("slider.shown = true")
pump(30)
# Animators keep the GUI-thread value at the target; the render thread moves it
check("showing: running on the render thread", ev("slider.moving"))
mid = win.grabWindow().pixelColor(100, 50)
pump(400)
check("shown: opaque, in place", ev("slider.opacity") == 1 and ev("slider.y") == 0 and not ev("slider.moving"))
end = win.grabWindow().pixelColor(100, 50)
check("drawn while showing and at the end", end.red() > 200 and end.green() < 60, f"{mid.name()} -> {end.name()}")

ev("slider.shown = false")
check("hidden: moving holds from the very same moment", ev("slider.moving"))
pump(60)
check("hiding: still moving mid-exit", ev("slider.moving"))
pump(400)
check("hidden: done moving, transparent", not ev("slider.moving") and ev("slider.opacity") == 0)
gone = win.grabWindow().pixelColor(100, 50)
check("nothing drawn once hidden", gone.red() < 30 or gone.alpha() == 0 or gone.name() in ("#000000", "#ffffff"), gone.name())

# Animations off (Motion durations 0): it switches at once, never lingers
ev("OsdMotion.exitMs = 0; OsdMotion.enterMs = 0; slider.shown = true")
pump(40)
check("animations off: shown at once", ev("slider.opacity") == 1 and not ev("slider.moving"), str((ev("slider.opacity"), ev("slider.moving"), ev("slider.leaving"))))
ev("slider.shown = false")
check("animations off: hidden at once, nothing to wait for", not ev("slider.leaving"))
pump(40)
check("animations off: done", not ev("slider.moving") and ev("slider.opacity") == 0)

print("OsdSlide:", "PASS" if ok_all else "FAIL")
h.exit(0 if ok_all else 1)
