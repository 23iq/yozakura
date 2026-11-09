"""The attached notch draws without per-frame canvas or layer work (GL,
private Xvfb):

* NotchOutline (QtQuick.Shapes path) draws the same stroke as the Canvas
  it replaced, on the top and bottom edges, for several sizes, corner
  sizes, radii and border widths;
* NotchSilhouette (attached) keeps no layer that follows its size: every
  layered item stays cornerSize while the silhouette morphs, and the
  surface it paints matches the old masked silhouette (a silhouette-sized
  fill masked by the concave corners + rounded body).
"""
import json
import os
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


h = Harness("notch-outline")
h.singleton("qs.config", "Config", """QtObject {
    property string notchTheme: "default"
    property int roundness: 16
    property int animDuration: 0
    property QtObject theme: QtObject { property QtObject srBg: QtObject { property var border: ["#ff3060", 2] } }
    function resolveColor(c) { return c; }
}""")
h.module("qs.modules.theme", {
    "Colors": "pragma Singleton\nQtObject { property color primary: 'red' }",
    "Motion": "pragma Singleton\nQtObject { property var morph: ({ duration: 0, easing: Easing.OutCubic, overshoot: 1 }) }",
})
# A flat fill stands in for the themed surface (same for old and new)
h.module("qs.modules.components", {"StyledRect": """Rectangle {
    property string variant; property string glassSurface; property bool cornerStyled; property bool enableBorder
    property bool animateRadius; property real rectOpacity: 1; property bool hasSolidColor: true; property color solidColor: color
    color: "#3060c0"; antialiasing: true
}"""})
h.module("qs.modules.corners", {"RoundCorner": (REPO / "modules/corners/RoundCorner.qml").read_text()})
notch_dir = REPO / "modules/notch"
nd = h.module("qs.modules.notch", {n: (notch_dir / f"{n}.qml").read_text() for n in ["NotchSilhouette", "NotchOutline"]})
(nd / "NotchShape.js").write_text((notch_dir / "NotchShape.js").read_text())

# The Canvas outline NotchOutline replaced (reference)
OLD_OUTLINE = """Canvas {
    id: c
    property string edge: "top"
    property int cornerSize: 0
    property real radius: 0
    property int borderWidth: 2
    property color borderColor: "#ff3060"
    onWidthChanged: requestPaint(); onHeightChanged: requestPaint(); onEdgeChanged: requestPaint()
    onCornerSizeChanged: requestPaint(); onRadiusChanged: requestPaint(); onBorderWidthChanged: requestPaint()
    antialiasing: true
    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (borderWidth <= 0) return;
        ctx.strokeStyle = borderColor; ctx.lineWidth = borderWidth; ctx.lineJoin = "round"; ctx.lineCap = "round";
        const o = borderWidth / 2, cs = cornerSize, r = radius, wCenter = width - cs * 2, yBottom = height - o;
        ctx.beginPath();
        if (edge === "top") {
            ctx.moveTo(o, o);
            if (cs > 0) ctx.arc(o, cs, cs - o, 3 * Math.PI / 2, 2 * Math.PI);
            ctx.lineTo(cs, yBottom - r);
            if (r > 0) ctx.arcTo(cs, yBottom, cs + r, yBottom, r - o);
            ctx.lineTo(cs + wCenter - r, yBottom);
            if (r > 0) ctx.arcTo(cs + wCenter, yBottom, cs + wCenter, yBottom - r, r - o);
            ctx.lineTo(cs + wCenter, cs);
            if (cs > 0) ctx.arc(width - o, cs, cs - o, Math.PI, 3 * Math.PI / 2);
        } else {
            ctx.moveTo(o, yBottom);
            if (cs > 0) ctx.arc(o, height - cs, cs - o, Math.PI / 2, 0, true);
            ctx.lineTo(cs, o + r);
            if (r > 0) ctx.arcTo(cs, o, cs + r, o, r - o);
            ctx.lineTo(cs + wCenter - r, o);
            if (r > 0) ctx.arcTo(cs + wCenter, o, cs + wCenter, o + r, r - o);
            ctx.lineTo(cs + wCenter, height - cs);
            if (cs > 0) ctx.arc(width - o, height - cs, cs - o, Math.PI, Math.PI / 2, true);
        }
        ctx.stroke();
    }
}"""
(h.root / "app").mkdir(exist_ok=True)
(h.root / "app/OldOutline.qml").write_text("import QtQuick\n" + OLD_OUTLINE + "\n")

# The masked silhouette NotchSilhouette replaced (reference, top edge)
(h.root / "app/OldAttached.qml").write_text("""import QtQuick
import QtQuick.Effects
import qs.modules.corners
Item {
    id: root
    property int cornerSize: 20
    property real outer: 24
    Rectangle { id: bg; anchors.fill: parent; color: "#3060c0"; visible: false; layer.enabled: true; layer.smooth: true }
    MultiEffect { anchors.fill: parent; source: bg; maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskThresholdMax: 1.0; maskSpreadAtMin: 1.0 }
    Item {
        id: mask; anchors.fill: parent; visible: false; layer.enabled: true; layer.smooth: true
        RoundCorner { anchors.left: parent.left; width: root.cornerSize; height: width; size: Math.max(width, 1); corner: RoundCorner.CornerEnum.TopRight; color: "white" }
        Rectangle { x: root.cornerSize; width: parent.width - root.cornerSize * 2; height: parent.height; color: "white"; bottomLeftRadius: root.outer; bottomRightRadius: root.outer }
        RoundCorner { anchors.right: parent.right; width: root.cornerSize; height: width; size: Math.max(width, 1); corner: RoundCorner.CornerEnum.TopLeft; color: "white" }
    }
}
""")

W, H = 640, 400
root = h.load(f"""import QtQuick
import qs.config
import qs.modules.notch
Item {{
    id: stage
    width: {W}; height: {H}
    property int mode: 0
    property string edge: "top"
    property real w: 300
    property real hh: 120
    property int cs: 20
    property real rad: 24
    property int bw: 2
    property alias silhouette: sil
    function layered(item, acc) {{
        if (item.layer && item.layer.enabled)
            acc.push([Math.round(item.width * 100) / 100, Math.round(item.height * 100) / 100]);
        for (let i = 0; i < item.children.length; i++)
            layered(item.children[i], acc);
        return acc;
    }}
    Rectangle {{ anchors.fill: parent; color: "white" }}
    // outline: new (mode 0) vs old canvas (mode 1)
    NotchOutline {{ x: 40; y: 40; width: stage.w; height: stage.hh; visible: stage.mode === 0
        edge: stage.edge; cornerSize: stage.cs; radius: stage.rad }}
    OldOutline {{ x: 40; y: 40; width: stage.w; height: stage.hh; visible: stage.mode === 1
        edge: stage.edge; cornerSize: stage.cs; radius: stage.rad; borderWidth: stage.bw }}
    // surface: new attached silhouette (mode 2) vs old masked one (mode 3), no outline
    NotchSilhouette {{ id: sil; x: 40; y: 0; width: stage.w; height: stage.hh; visible: stage.mode === 2
        position: "top"; cornerSize: stage.cs; open: false; unifiedEffectActive: true }}
    OldAttached {{ x: 40; y: 0; width: stage.w; height: stage.hh; visible: stage.mode === 3
        cornerSize: stage.cs; outer: sil.outer }}
}}""", auto_stub=False)

win = QQuickWindow()
win.resize(W, H)
root.setParentItem(win.contentItem())
win.show()


def grab(mode):
    h.eval(root, f"mode = {mode}")
    pump(120)
    return win.grabWindow()


def compare(a, b):
    """Over the drawn area only (stage.w x stage.hh at 40,0..40, plus a margin)."""
    w, hh = int(h.eval(root, "w")), int(h.eval(root, "hh"))
    worst, at, bad = 0, (0, 0), 0
    for y in range(0, min(H, hh + 50)):
        for x in range(30, min(W, w + 52)):
            ca, cb = a.pixelColor(x, y), b.pixelColor(x, y)
            d = max(abs(ca.red() - cb.red()), abs(ca.green() - cb.green()), abs(ca.blue() - cb.blue()))
            if d > 128:
                bad += 1
            if d > worst:
                worst, at = d, (x, y)
    return worst, at, bad


# Outline: antialiasing differs between a Canvas raster and a GPU path, so
# only pixels off by more than 128/255 count, and a few may (stroke ends)
for edge in ("top", "bottom"):
    for w, hh, cs, rad, bw in ((300, 120, 20, 24, 2), (180.5, 64, 16, 20, 1), (420, 90, 0, 0, 2), (260, 140, 24, 40, 3)):
        h.eval(root, f"edge = '{edge}'; w = {w}; hh = {hh}; cs = {cs}; rad = {rad}; bw = {bw}; "
                     f"Config.theme.srBg.border = ['#ff3060', {bw}]")
        new, old = grab(0), grab(1)
        if os.environ.get("NOTCH_OUTLINE_DUMP"):
            new.save(f"{os.environ['NOTCH_OUTLINE_DUMP']}/{edge}-{w}-{cs}-{rad}-{bw}-new.png")
            old.save(f"{os.environ['NOTCH_OUTLINE_DUMP']}/{edge}-{w}-{cs}-{rad}-{bw}-old.png")
        worst, at, bad = compare(new, old)
        check(f"outline {edge} {w}x{hh} corner {cs} radius {rad} border {bw} matches the canvas",
              bad <= 12, f"({bad} px off by > 128, worst {worst} at {at})")

h.eval(root, "edge = 'top'; w = 300; hh = 120; cs = 20; rad = 24; Config.theme.srBg.border = ['#ff3060', 2]")


def layered_sizes():
    """Sizes of every layered item inside the silhouette (walked in QML)."""
    return [tuple(s) for s in json.loads(h.eval(root, "JSON.stringify(layered(silhouette, []))"))]


for w, hh in ((300, 120), (333.5, 77), (520, 210)):
    h.eval(root, f"w = {w}; hh = {hh}")
    pump(30)
    sizes = layered_sizes()
    check(f"no silhouette-sized layer at {w}x{hh}", sizes and all(s == (20, 20) for s in sizes), str(sizes))
    new, old = grab(2), grab(3)
    worst, at, bad = compare(new, old)
    check(f"attached surface {w}x{hh} matches the masked one", bad <= 2 * hh, f"({bad} px off by > 128, worst {worst} at {at})")

print("NotchOutline:", "PASS" if ok_all else "FAIL")
h.exit(0 if ok_all else 1)
