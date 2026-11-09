"""ShapeShadow (analytic SDF shadow) draws the same shadow as the captured
MultiEffect one it replaces (ShadowCaster); GL under a private Xvfb.

* a rounded box at several blur amounts, offsets and opacities;
* the attached notch silhouette (box + concave edge fillets) on every edge;
* the frame (everything outside a rounded hole);
* a morphing box costs no texture: ShapeShadow is a plain ShaderEffect,
  never a layer, and follows its box every frame.

SHAPE_SHADOW_DUMP=<dir> saves both renders of every case;
SHAPE_SHADOW_CAL=<dir> only saves MultiEffect renders of a square box at
blur 0, 0.05, ..., 1 (opacity 1), the data ShadowBlur.js's weights were
fitted to.
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


h = Harness("shape-shadow")
h.singleton("qs.config", "Config", """QtObject {
    property QtObject theme: QtObject { property real shadowBlur: 1; property real shadowOpacity: 0.6; property string shadowColor: "shadow"; property real shadowXOffset: 0; property real shadowYOffset: 0 }
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
h.copy("modules/components/ShadowCaster.qml")
h.copy("modules/components/shape/ShapeShadow.qml")
h.copy("modules/corners/RoundCorner.qml")

W, H = 640, 400
root = h.load(f"""import QtQuick
import qs.config
Item {{
    id: stage
    width: {W}; height: {H}
    // 0 box, 1 attached notch, 2 frame
    property int shape: 0
    property string edge: "top"
    property real r: 18
    property real fil: 20
    property rect box: shape === 2 ? Qt.rect(30, 40, {W} - 60, {H} - 70)
        : shape === 0 ? Qt.rect(160, 110, 320, 170)
        : edge === "left" ? Qt.rect(0, 80, 140, 240)
        : edge === "right" ? Qt.rect({W} - 140, 80, 140, 240)
        : edge === "bottom" ? Qt.rect(170, {H} - 130, 300, 130)
        : Qt.rect(170, 0, 300, 130)
    property int mode: 0
    property alias analytic: analytic
    Rectangle {{ anchors.fill: parent; color: "white" }}

    // Reference: the shape drawn (nearly invisible) and cast by ShadowCaster
    ShadowCaster {{ visible: stage.mode === 0; source: src; sourceRect: Qt.rect(0, 0, {W}, {H}) }}
    Item {{
        id: src; anchors.fill: parent; z: 1
        readonly property bool alongX: stage.edge === "top" || stage.edge === "bottom"
        Rectangle {{
            visible: stage.shape !== 2
            readonly property real f: stage.shape === 1 ? stage.fil : 0
            x: stage.box.x + (src.alongX ? f : 0); y: stage.box.y + (src.alongX ? 0 : f)
            width: stage.box.width - (src.alongX ? 2 * f : 0); height: stage.box.height - (src.alongX ? 0 : 2 * f)
            color: "white"
            topLeftRadius: stage.shape === 1 && (stage.edge === "top" || stage.edge === "left") ? 0 : stage.r
            topRightRadius: stage.shape === 1 && (stage.edge === "top" || stage.edge === "right") ? 0 : stage.r
            bottomLeftRadius: stage.shape === 1 && (stage.edge === "bottom" || stage.edge === "left") ? 0 : stage.r
            bottomRightRadius: stage.shape === 1 && (stage.edge === "bottom" || stage.edge === "right") ? 0 : stage.r
        }}
        // concave fillets, as NotchSilhouette's mask draws them
        Repeater {{
            model: stage.shape === 1 ? 2 : 0
            delegate: RoundCorner {{
                required property int index
                readonly property bool first: index === 0
                size: stage.fil; width: stage.fil; height: stage.fil; color: "white"
                x: src.alongX ? (first ? stage.box.x : stage.box.x + stage.box.width - stage.fil) : (stage.edge === "left" ? 0 : {W} - stage.fil)
                y: src.alongX ? (stage.edge === "top" ? 0 : {H} - stage.fil) : (first ? stage.box.y : stage.box.y + stage.box.height - stage.fil)
                corner: stage.edge === "top" ? (first ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.TopLeft)
                    : stage.edge === "bottom" ? (first ? RoundCorner.CornerEnum.BottomRight : RoundCorner.CornerEnum.BottomLeft)
                    : stage.edge === "left" ? (first ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.TopLeft)
                    : (first ? RoundCorner.CornerEnum.BottomRight : RoundCorner.CornerEnum.TopRight)
            }}
        }}
        // frame: everything outside the rounded hole
        Item {{
            visible: stage.shape === 2; anchors.fill: parent
            Rectangle {{ width: parent.width; height: stage.box.y; color: "white" }}
            Rectangle {{ y: stage.box.y + stage.box.height; width: parent.width; height: parent.height - y; color: "white" }}
            Rectangle {{ y: stage.box.y; width: stage.box.x; height: stage.box.height; color: "white" }}
            Rectangle {{ x: stage.box.x + stage.box.width; y: stage.box.y; width: parent.width - x; height: stage.box.height; color: "white" }}
            Repeater {{
                model: 4
                delegate: RoundCorner {{
                    required property int index
                    size: stage.r; width: stage.r; height: stage.r; color: "white"
                    x: index % 2 === 0 ? stage.box.x : stage.box.x + stage.box.width - stage.r
                    y: index < 2 ? stage.box.y : stage.box.y + stage.box.height - stage.r
                    corner: [RoundCorner.CornerEnum.TopLeft, RoundCorner.CornerEnum.TopRight, RoundCorner.CornerEnum.BottomLeft, RoundCorner.CornerEnum.BottomRight][index]
                }}
            }}
        }}
    }}
    // The shape (z: 1) is painted white over both, so only the shadow is compared
    ShapeShadow {{
        id: analytic
        visible: stage.mode === 1
        box: stage.box
        inverted: stage.shape === 2
        fillet: stage.shape === 1 ? stage.fil : 0
        edge: stage.edge
        radii: stage.shape === 1 ? Qt.vector4d(
                stage.edge === "top" || stage.edge === "left" ? 0 : stage.r,
                stage.edge === "top" || stage.edge === "right" ? 0 : stage.r,
                stage.edge === "bottom" || stage.edge === "right" ? 0 : stage.r,
                stage.edge === "bottom" || stage.edge === "left" ? 0 : stage.r)
            : Qt.vector4d(stage.r, stage.r, stage.r, stage.r)
    }}
}}""", auto_stub=False)

win = QQuickWindow()
win.resize(W, H)
root.setParentItem(win.contentItem())
win.show()


def grab(mode):
    h.eval(root, f"mode = {mode}")
    pump(160)
    return win.grabWindow()


def compare(a, b):
    """Worst channel difference and where it is."""
    worst = (0, 0, 0)
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            ca, cb = a.pixelColor(x, y), b.pixelColor(x, y)
            d = max(abs(ca.red() - cb.red()), abs(ca.green() - cb.green()), abs(ca.blue() - cb.blue()))
            if d > worst[0]:
                worst = (d, x, y)
    return worst


def case(name, js, tol=TOL):
    h.eval(root, js)
    ref = grab(0)
    new = grab(1)
    d, x, y = compare(ref, new)
    if os.environ.get("SHAPE_SHADOW_DUMP"):
        out = Path(os.environ["SHAPE_SHADOW_DUMP"])
        slug = name.replace(" ", "-").replace(",", "")
        ref.save(str(out / f"{slug}-captured.png"))
        new.save(str(out / f"{slug}-analytic.png"))
    check(name, d <= tol, f"(max channel diff {d} at {x},{y})")
    return d


if os.environ.get("SHAPE_SHADOW_CAL"):
    for i in range(0, 21):
        b = i / 20
        h.eval(root, f"Config.theme.shadowBlur = {b}; Config.theme.shadowOpacity = 1; shape = 0; r = 0")
        grab(0).save(f"{os.environ['SHAPE_SHADOW_CAL']}/cal-{i}.png")
    h.exit(0)
for blur in (0.0, 0.25, 0.5, 1.0):
    # Unblurred, only the antialiased rim differs (SDF vs Rectangle's own AA)
    case(f"rounded box, blur {blur}", f"Config.theme.shadowBlur = {blur}; Config.theme.shadowXOffset = 3; "
         "Config.theme.shadowYOffset = 5; shape = 0; edge = 'top'; r = 18", 20 if blur == 0 else TOL)
case("square box", "Config.theme.shadowBlur = 0.6; shape = 0; r = 0")
case("offset and opacity", "Config.theme.shadowBlur = 0.6; Config.theme.shadowXOffset = 4; "
     "Config.theme.shadowYOffset = 7; Config.theme.shadowOpacity = 0.35; r = 30")
h.eval(root, "Config.theme.shadowXOffset = 0; Config.theme.shadowYOffset = 3; Config.theme.shadowOpacity = 0.6")
for edge in ("top", "bottom", "left", "right"):
    case(f"attached notch on {edge}", f"Config.theme.shadowBlur = 0.6; shape = 1; edge = '{edge}'; r = 24; fil = 20")
for rad in (22, 0):
    case(f"frame hole radius {rad}", f"Config.theme.shadowBlur = 0.6; shape = 2; edge = 'top'; r = {rad}")

# No offscreen texture: a ShaderEffect without a layer, whatever the box
check("analytic shadow is not a layer", h.eval(root, "analytic.layer.enabled") is False)
h.eval(root, "shape = 0; mode = 1; box = Qt.rect(100, 100, 50, 40)")
pump(60)
check("follows its box", abs(h.eval(root, "analytic.x") - (100 - h.eval(root, "analytic.spill"))) < 0.01)

print("ShapeShadow:", "PASS" if ok_all else "FAIL")
h.exit(0 if ok_all else 1)
