"""The notch's notification popup casts the theme shadow (PanelShadows),
GL under a private Xvfb.

The real PanelShadows with a notch stand-in exposing NotchContent's shadow
geometry (silhouette, silhouetteRect, notificationPopupRect/Radius/Alpha,
reveal and fade). The popup's analytic shadow must match what the old
captured shadow of the notch region (ShadowCaster over notch + popup) drew
around the popup, follow the popup's reveal and vanish with it.

NOTCH_POPUP_SHADOW_DUMP=<dir> saves both renders.
"""
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib import headless  # noqa: E402

headless.ensure(gl=True)
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402

ok_all = True
# Max channel difference (8 bit) between the analytic and the captured shadow
TOL = 8


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


h = Harness("notch-popup-shadow")
h.singleton("qs.config", "Config", """QtObject {
    property real roundness: 16
    property var bar: ({ frameEnabled: false, frameThickness: 6 })
    property QtObject theme: QtObject { property real shadowBlur: 0.6; property real shadowOpacity: 0.6; property string shadowColor: "shadow"; property real shadowXOffset: 0; property real shadowYOffset: 3 }
    function resolveColor(c) { return "#102040"; }
}""")
h.module("qs.modules.theme", {
    "Lighting": """pragma Singleton
import qs.config
QtObject {
    readonly property int shadowXOffset: Config.theme.shadowXOffset
    readonly property int shadowYOffset: Config.theme.shadowYOffset
    readonly property real shadowBlur: Config.theme.shadowBlur
    readonly property real shadowOpacity: Config.theme.shadowOpacity
    readonly property color shadowColor: Config.resolveColor(Config.theme.shadowColor)
}""",
})
h.module("qs.modules.globals", {})
h.copy("modules/components/ShadowCaster.qml", "qs/modules/components", siblings=False)
h.copy("modules/components/RenderFade.qml", "qs/modules/components", siblings=False)
h._write_qmldir(h.root / "qs/modules/components", "qs.modules.components")
h.copy("modules/components/shape/ShapeShadow.qml", "qs/modules/components/shape", siblings=False)
h._write_qmldir(h.root / "qs/modules/components/shape", "qs.modules.components.shape")
h.copy("modules/shell/PanelShadows.qml", "qs/modules/shell", siblings=False)
h.copy("modules/shell/FrameShapeShadow.qml", "qs/modules/shell", siblings=False)
h.copy("modules/shell/ShadowHoleClip.qml", "qs/modules/shell", siblings=False)
h._write_qmldir(h.root / "qs/modules/shell", "qs.modules.shell")

W, H = 640, 420
root = h.load(f"""import QtQuick
import qs.modules.components
import qs.modules.shell
Item {{
    id: stage
    width: {W}; height: {H}
    property int mode: 0
    property bool reveal: true
    property rect popup: Qt.rect(140, 120, 368, 180)
    property real popupRadius: 20
    Rectangle {{ anchors.fill: parent; color: "white" }}

    // Reference: the old captured shadow of the notch region (popup drawn
    // white over it, so only the shadow is compared)
    ShadowCaster {{ visible: stage.mode === 0; source: src; sourceRect: Qt.rect(0, 0, {W}, {H}) }}
    // New: the analytic one (PanelShadows, notch stand-in)
    PanelShadows {{
        anchors.fill: parent
        visible: stage.mode === 1
        barEnabled: false
        dockEnabled: false
        notch: Item {{
            visible: true
            readonly property var silhouette: null
            readonly property rect silhouetteRect: Qt.rect(0, 0, 0, 0)
            readonly property rect notificationPopupRect: stage.popup
            readonly property real notificationPopupRadius: stage.popupRadius
            readonly property real notificationPopupAlpha: 1
            readonly property bool reveal: stage.reveal
            readonly property int fadeDuration: 0
            readonly property int fadeEasing: Easing.Linear
        }}
    }}
    Item {{
        id: src; anchors.fill: parent; z: 1
        Rectangle {{
            x: stage.popup.x; y: stage.popup.y; width: stage.popup.width; height: stage.popup.height
            radius: stage.popupRadius; color: "white"
        }}
    }}
}}""", auto_stub=False)

win = QQuickWindow()
win.resize(W, H)
root.setParentItem(win.contentItem())
win.show()


def grab(mode):
    h.eval(root, f"mode = {mode}")
    pump(200)
    return win.grabWindow()


def compare(a, b):
    worst = (0, 0, 0)
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            ca, cb = a.pixelColor(x, y), b.pixelColor(x, y)
            d = max(abs(ca.red() - cb.red()), abs(ca.green() - cb.green()), abs(ca.blue() - cb.blue()))
            if d > worst[0]:
                worst = (d, x, y)
    return worst


ref = grab(0)
new = grab(1)
if os.environ.get("NOTCH_POPUP_SHADOW_DUMP"):
    out = Path(os.environ["NOTCH_POPUP_SHADOW_DUMP"])
    ref.save(str(out / "popup-shadow-captured.png"))
    new.save(str(out / "popup-shadow-analytic.png"))
d, x, y = compare(ref, new)
check("popup shadow matches the captured notch-region shadow", d <= TOL, f"(max channel diff {d} at {x},{y})")
below = new.pixelColor(320, 120 + 180 + 6)
check("a shadow is drawn under the popup", below.red() < 250, below.name())

h.eval(root, "reveal = false")
pump(200)
hidden = win.grabWindow().pixelColor(320, 120 + 180 + 6)
check("hidden with the popup's reveal", hidden.name() == "#ffffff", hidden.name())
h.eval(root, "reveal = true; popup = Qt.rect(0, 0, 0, 0)")
pump(200)
gone = win.grabWindow().pixelColor(320, 120 + 180 + 6)
check("no shadow without a popup", gone.name() == "#ffffff", gone.name())

print("notch popup shadow:", "PASS" if ok_all else "FAIL")
h.exit(0 if ok_all else 1)
