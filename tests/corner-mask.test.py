"""StyledRect corner styles, rendered offscreen (GL): round keeps the plain
ClippingRectangle path (no layer, content stays in the clip), squircle / cut /
tab render through the CornerMask SDF shader with crisp, antialiased corners,
and switching back to round restores the original tree.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

import settings_env  # noqa: E402
from PySide6.QtGui import QColor  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402

# A ClippingRectangle with Quickshell's shape: children live in a clipped
# contentItem, the background is a rounded Rectangle under it.
settings_env.QUICKSHELL_WIDGETS = dict(settings_env.QUICKSHELL_WIDGETS, ClippingRectangle="""Item {
    id: cr
    property bool contentUnderBorder: false
    property alias color: bg.color
    property alias radius: bg.radius
    property alias topLeftRadius: bg.topLeftRadius
    property alias topRightRadius: bg.topRightRadius
    property alias bottomLeftRadius: bg.bottomLeftRadius
    property alias bottomRightRadius: bg.bottomRightRadius
    property alias border: bg.border
    default property alias content: ci.data
    readonly property alias contentItem: ci
    Rectangle { id: bg; anchors.fill: parent; antialiasing: true }
    Item { id: holder; objectName: "clipHolder"; anchors.fill: parent; clip: true
        Item { id: ci; anchors.fill: parent } }
}""")

# Classic visual language: the variants drawn exactly as configured.
env = settings_env.SettingsEnv("corner-mask", overrides={"theme": {"language": "classic"}})
h = env.h
failures: list[str] = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.components
Window {
    id: w
    width: 300; height: 200; visible: true; color: "#00ff00"
    property alias rect: r
    function setShape(corners) { Config.theme.shape = Object.assign({}, Config.theme.shape, {corners: corners}) }
    StyledRect {
        id: r
        x: 20; y: 20; width: 200; height: 120
        variant: "primary"
        enableBorder: false
        radius: 16
        Rectangle { objectName: "child"; anchors.fill: parent; color: "transparent" }
    }
}""")


def ev(expr):
    return h.eval(win, expr)


def px(x, y) -> QColor:
    QTest.qWait(60)
    img = win.grabWindow()
    return img.pixelColor(20 + x, 20 + y)


def is_bg(c: QColor) -> bool:
    return c.green() > 200 and c.red() < 60 and c.blue() < 60


def is_fill(c: QColor) -> bool:
    return c.red() > 200 and c.green() < 220 and not is_bg(c)


# round: the default, plain path
check(ev("w.rect.cornerMasked") is False, "round is not masked")
check(ev("w.rect.layer.enabled") is False, "round has no layer")
check(ev("w.rect.contentItem.parent.objectName") == "clipHolder", "round keeps content in the clip")
check(is_bg(px(1, 1)), "round: the corner pixel is outside")
check(is_fill(px(100, 60)), "round: the center is filled")
check(is_bg(px(3, 3)), "round: (3,3) is outside the 16px arc")

# cut
ev('w.setShape("cut")')
QTest.qWait(50)
check(ev("w.rect.cornerMasked") is True, "cut is masked")
check(ev("w.rect.layer.enabled") is True, "cut renders through a layer")
check(ev("w.rect.contentItem.parent === w.rect"), "cut lifts content out of the round clip")
check(is_bg(px(1, 1)), "cut: corner pixel is outside")
check(is_bg(px(4, 4)), "cut: (4,4) is outside the 10px chamfer")
check(is_fill(px(8, 8)), "cut: (8,8) is inside the chamfer")
check(is_fill(px(12, 0)), "cut: the top edge past the chamfer is filled")
check(is_fill(px(100, 60)), "cut: center is filled")
check(is_bg(px(199, 119)), "cut: bottom-right corner is outside")

# squircle: fuller than the circle at the diagonal
ev('w.setShape("squircle")')
QTest.qWait(50)
check(ev("w.rect.cornerMasked") is True, "squircle is masked")
check(is_bg(px(0, 0)), "squircle: corner pixel is outside")
check(is_fill(px(5, 5)), "squircle: (5,5) is inside (fuller than the arc)")
check(is_fill(px(100, 60)), "squircle: center is filled")

# antialiasing: some pixel along the cut diagonal is partially covered
ev('w.setShape("cut")')
QTest.qWait(50)
mixed = [px(i, 9 - i) for i in range(0, 10)]
check(any(not is_bg(c) and not is_fill(c) for c in mixed), "cut: the chamfer edge is antialiased")

# tab: squares the corners on the anchor edge only
ev('w.setShape("tab")')
ev('w.rect.anchorEdge = ""')
QTest.qWait(50)
check(ev("w.rect.cornerMasked") is False, "tab without an anchor edge stays on the round path")
ev('w.rect.anchorEdge = "top"')
QTest.qWait(50)
check(ev("w.rect.cornerMasked") is True, "tab with an anchor edge is masked")
check(is_fill(px(0, 0)), "tab: top-left is square")
check(is_fill(px(199, 0)), "tab: top-right is square")
check(is_bg(px(0, 119)), "tab: bottom-left stays round")

# back to round: the original tree and look
ev('w.setShape("round")')
QTest.qWait(50)
check(ev("w.rect.cornerMasked") is False, "round again is not masked")
check(ev("w.rect.layer.enabled") is False, "round again has no layer")
check(ev("w.rect.contentItem.parent.objectName") == "clipHolder", "round again puts content back in the clip")
check(is_bg(px(3, 3)) and is_fill(px(100, 60)), "round again renders as before")

# shadow: the round path's MultiEffect pads the layer; the mask drops it
ev("w.rect.enableShadow = true")
QTest.qWait(50)
check(ev("w.rect.layer.sourceRect.width") != 0, "round shadow pads the layer")
ev('w.setShape("cut")')
QTest.qWait(50)
check(ev("w.rect.layer.sourceRect.width") == 0, "masked layer samples the bare item")
check(is_fill(px(100, 60)) and is_bg(px(1, 1)), "cut with shadow keeps its shape")
ev('w.setShape("round")')
ev("w.rect.enableShadow = false")
QTest.qWait(50)

# a corrupt style falls back to round
ev('w.setShape("blob")')
QTest.qWait(50)
check(ev("w.rect.cornerMasked") is False, "unknown style falls back to round")

print("corner-mask:", "OK" if not failures else f"{len(failures)} failure(s)")
sys.exit(1 if failures else 0)
