"""Unified panel surfaces without full-screen layers (GL, private Xvfb).

* ShadowCaster draws the same shadow as the `Shadow` MultiEffect it
  replaces (theme blur/opacity/colour), including after its capture
  rectangle changes size (MultiEffect must see the new source size), and
  draws nothing over its source.
* FrameFill (strips + masked inner corners) renders the frame exactly like
  the old full-screen StyledRect behind an inverted MultiEffect mask, with a
  gradient fill so misaligned pieces would show.
"""
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


h = Harness("panel-shadows")
h.singleton("qs.config", "Config", """QtObject {
    property QtObject theme: QtObject { property real shadowBlur: 1; property real shadowOpacity: 0.5; property string shadowColor: "shadow"; property real shadowXOffset: 2; property real shadowYOffset: 3 }
    function resolveColor(c) { return "#202040"; }
}""")
h.module("qs.modules.components", {"StyledRect": """Rectangle {
    property string variant; property bool enableBorder
    gradient: Gradient { GradientStop { position: 0; color: "#f04020" } GradientStop { position: 1; color: "#2060f0" } }
}"""})
h.copy("modules/components/ShadowCaster.qml")
h.module("qs.modules.theme", {"Styling": "pragma Singleton\nQtObject { function radius(o) { return 0 } }"})
h.copy("modules/frame/FrameFill.qml")
h.copy("modules/frame/FrameLines.qml")

W, H = 600, 400
root = h.load(f"""import QtQuick
import QtQuick.Effects
import qs.config
import qs.modules.components
Item {{
    id: stage
    width: {W}; height: {H}
    property rect capture: Qt.rect(0, 0, 300, 60)
    property int mode: 0
    Rectangle {{ anchors.fill: parent; color: "white" }}
    // Left half: ShadowCaster beneath its source; right half: Shadow reference
    Item {{
        width: 300; height: {H}; visible: stage.mode === 0
        ShadowCaster {{ source: src; sourceRect: stage.capture }}
        Item {{ id: src; anchors.fill: parent
            Rectangle {{ x: 40; y: 80; width: 60; height: 200; radius: 12; color: "#60c060" }} }}
    }}
    Item {{
        x: 300; width: 300; height: {H}; visible: stage.mode === 0
        Item {{ anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {{ shadowEnabled: true; shadowBlur: Config.theme.shadowBlur; shadowOpacity: Config.theme.shadowOpacity
                shadowColor: Config.resolveColor(""); shadowHorizontalOffset: Config.theme.shadowXOffset; shadowVerticalOffset: Config.theme.shadowYOffset }}
            Rectangle {{ x: 40; y: 80; width: 60; height: 200; radius: 12; color: "#60c060" }} }}
    }}
    // Frame: new pieces vs old full-screen mask
    property real thick: 14
    property real rad: 22
    FrameFill {{
        anchors.fill: parent; visible: stage.mode === 1
        leftThickness: stage.thick; topThickness: stage.thick * 3; rightThickness: stage.thick; bottomThickness: stage.thick * 2
        innerRadius: stage.rad
    }}
    Item {{
        anchors.fill: parent; visible: stage.mode === 2
        StyledRect {{ id: oldFill; anchors.fill: parent; variant: "frame"
            layer.enabled: true
            layer.effect: MultiEffect {{ maskEnabled: true; maskSource: oldMask; maskInverted: true; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }} }}
        Item {{ id: oldMask; anchors.fill: parent; visible: false; layer.enabled: true
            Rectangle {{ x: stage.thick; y: stage.thick * 3; width: parent.width - stage.thick * 2; height: parent.height - stage.thick * 5; radius: stage.rad; color: "white" }} }}
    }}
}}""", auto_stub=False)

win = QQuickWindow()
win.resize(W, H)
root.setParentItem(win.contentItem())
win.show()


def diff(a, b, box_a, box_b, skip=None):
    worst = 0
    for y in range(box_a[1], box_a[3], 2):
        for x in range(box_a[0], box_a[2], 2):
            if skip and skip[0] <= x < skip[2] and skip[1] <= y < skip[3]:
                continue
            ca, cb = a.pixelColor(x, y), b.pixelColor(x - box_a[0] + box_b[0], y - box_a[1] + box_b[1])
            worst = max(worst, abs(ca.red() - cb.red()), abs(ca.green() - cb.green()), abs(ca.blue() - cb.blue()))
    return worst


# The capture starts too small, then grows to the real region: the shadow
# must follow the new size.
pump(300)
h.eval(root, "capture = Qt.rect(0, 40, 160, 280)")
pump(400)
img = win.grabWindow()
# Shadow pixels (the shape's own 1 px antialiased rim is composited with
# plain source-over now; MultiEffect scaled it by the shadow mix)
d = diff(img, img, (0, 0, 300, H), (300, 0, 600, H), skip=(38, 78, 102, 282))
check("ShadowCaster matches the Shadow MultiEffect after a resize", d <= 3, f"(max channel diff {d})")
rim = diff(img, img, (38, 78, 102, 282), (338, 78, 402, 282))
check("shape rim within the source-over difference", rim <= 40, f"(max channel diff {rim})")
inside = img.pixelColor(70, 180)
check("no copy of the source drawn", (inside.red(), inside.green(), inside.blue()) == (0x60, 0xc0, 0x60), inside.name())
h.eval(root, "Config.theme.shadowOpacity = 0")
pump(200)
img2 = win.grabWindow()
check("opacity 0 hides it", img2.pixelColor(120, 300).name() == "#ffffff", img2.pixelColor(120, 300).name())
h.eval(root, "Config.theme.shadowOpacity = 0.5")

for thick, rad in [(14, 22), (6, 0), (20, 40), (9, 13.5)]:
    h.eval(root, f"thick = {thick}; rad = {rad}; mode = 1")
    pump(150)
    new = win.grabWindow()
    h.eval(root, "mode = 2")
    pump(150)
    old = win.grabWindow()
    d = diff(new, old, (0, 0, W, H), (0, 0, W, H))
    check(f"FrameFill == masked frame (thickness {thick}, radius {rad})", d <= 2, f"(max channel diff {d})")

print("PanelShadows:", "PASS" if ok_all else "FAIL")
h.exit(0 if ok_all else 1)
