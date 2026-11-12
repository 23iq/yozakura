"""performance.splitFrame (phase 1 of docs/perf-panel-split.md): the frame
in its own Top-layer window instead of inside the unified panel.

* FrameSplit (who draws the frame): off by default, the panel draws it and
  no window exists; on, the window maps at once and the panel stops drawing
  a moment later; under a fullscreen window the panel draws it again at
  once and the window unmaps only once that state has settled (a quick
  fullscreen toggle maps and unmaps nothing); turning the flag or the frame
  off removes the window at once.
* FrameWindow: a full-screen layer surface on the Top layer with its own
  namespace, an empty input mask and no exclusive zone, showing what the
  split says.
* Pixels, in every visual language (tests/lib/languages.py), with the frame
  on, the real ScreenFrameContent, PanelShadows and bar panels (contained
  and floating bars), an attached notch and an attached dock casting their
  analytic shadows: the frame window (wallpaper + frame shadow + frame)
  with the panel's layer composited over it (clipped shadows, bars, notch,
  dock; no frame) against the unified panel drawing it all in one scene.
  Pixels may differ only where a shadow meets the frame: at antialiased
  edges of the frame's rounded hole, and wherever the frame is translucent
  (a shadow that passed under it is cut at its edge now). The test prints
  how many pixels differ and where, per language.

FRAME_SPLIT_SHOTS=<dir> saves the unified, composited and diff images.
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)
from languages import LANGUAGES  # noqa: E402
from qmlharness import Harness  # noqa: E402
from waits import pump, settle, wait_until  # noqa: E402

from PySide6.QtCore import QRect  # noqa: E402
from PySide6.QtGui import QColor, QImage, QPainter  # noqa: E402

SHOTS = os.environ.get("FRAME_SPLIT_SHOTS", "")
ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


# ── FrameSplit ────────────────────────────────────────────────────────
h = Harness("frame-split")
h.copy("modules/components/SettleGate.qml", "qs/modules/components")
h.module("qs.modules.components", {})
h.copy("modules/shell/FrameSplit.qml")
root = h.load("""import QtQuick
Item {
    property alias split: split
    property int windowFlips: 0
    property int panelFlips: 0
    FrameSplit {
        id: split
        settleInterval: 120
        handoverMs: 30
        onWindowShownChanged: windowFlips++
        onPanelDrawsChanged: panelFlips++
    }
}""", auto_stub=False)


def ev(expr):
    return h.eval(root, expr)


def state():
    return (ev("split.windowWanted"), ev("split.windowShown"), ev("split.panelDraws"))


check("off: the panel draws the frame, no window", state() == (False, False, True))
ev("split.frameEnabled = true")
check("off with the frame on: still the panel only", state() == (False, False, True))
ev("windowFlips = 0; panelFlips = 0; split.enabled = true")
check("on: the window maps at once, the panel still draws", state() == (True, True, True))
check("on: the panel stops drawing after the handover", wait_until(lambda: state() == (True, True, False)))
ev("windowFlips = 0; panelFlips = 0; split.fullscreen = true")
check("fullscreen: the panel draws at once, the window stays until settled", state() == (True, True, True), str(state()))
check("fullscreen: the window unmaps once settled", wait_until(lambda: state() == (True, False, True)))
check("fullscreen: one flip each", ev("windowFlips") == 1 and ev("panelFlips") == 1, f"{ev('windowFlips')} {ev('panelFlips')}")
ev("windowFlips = 0; panelFlips = 0; split.fullscreen = false")
check("fullscreen gone: the window maps at once", state()[1] is True)
check("fullscreen gone: the window takes over", wait_until(lambda: state() == (True, True, False)))
ev("windowFlips = 0; split.fullscreen = true")
pump(40)
ev("split.fullscreen = false")
pump(300)
check("quick fullscreen toggle: the window never unmaps", ev("windowFlips") == 0 and state() == (True, True, False),
      f"{ev('windowFlips')} {state()}")
ev("split.enabled = false")
check("flag off: no window, the panel draws, at once", state() == (False, False, True))
ev("split.enabled = true")
wait_until(lambda: state() == (True, True, False))
ev("split.frameEnabled = false")
check("frame off: no window at once", state() == (False, False, True))

# ── FrameWindow (layer surface) ───────────────────────────────────────
h.module("Quickshell", {
    "PanelWindow": """Item {
        property var screen; property color color; property int exclusionMode: -1; property var mask
        property WindowEdges edges: WindowEdges {}
    }""",
    "WindowEdges": "QtObject { property bool top; property bool bottom; property bool left; property bool right }",
    "Region": "QtObject { property Item item: Item {} }",
    "ExclusionMode": "QtObject { enum Mode { Normal, Ignore, Auto } }",
    "ShellScreen": "QtObject { property string name }",
})
h.module("Quickshell.Wayland", {"WlrLayer": "QtObject { enum Layer { Background, Bottom, Top, Overlay } }",
                                "WlrKeyboardFocus": "QtObject { enum Focus { None, Exclusive, OnDemand } }"})
h.module("qs.modules.frame", {"ScreenFrameContent": "Item { property var targetScreen; property bool hasFullscreenWindow }"})
h.module("qs.modules.globals", {})
h.stub("FrameShapeShadow", "Item { property var frame }")
h.copy("modules/shell/FrameWindow.qml", siblings=False, replace={
    "    anchors {\n": "    edges {\n",
    "WlrLayershell.namespace:": "property string layerNamespace:",
    "WlrLayershell.layer:": "property int layerShellLayer:",
    "WlrLayershell.keyboardFocus:": "property int layerKeyboardFocus:",
})
fw = h.load("""import QtQuick
import Quickshell
import qs.modules.globals
Item {
    property alias split: split
    property alias win: win
    ShellScreen { id: scr; name: "DP-1" }
    FrameSplit { id: split; settleInterval: 60; handoverMs: 10; frameEnabled: true }
    FrameWindow { id: win; targetScreen: scr; split: split }
}""", auto_stub=False)
desc = json.loads(h.eval(fw, """JSON.stringify({
    layer: win.layerShellLayer, ns: win.layerNamespace, focus: win.layerKeyboardFocus,
    ignore: win.exclusionMode === ExclusionMode.Ignore, mask: win.mask ? win.mask.item : "none",
    edges: [win.edges.top, win.edges.bottom, win.edges.left, win.edges.right], transparent: win.color.a === 0 })"""))
check("frame window: Top layer, own namespace, no keyboard, no zone, no input, transparent, full screen",
      desc == {"layer": 2, "ns": h.eval(fw, 'Brand.namespace("frame")'), "focus": 0, "ignore": True, "mask": None,
               "edges": [True, True, True, True], "transparent": True}, json.dumps(desc))
check("frame window: hidden while the split says so", h.eval(fw, "win.visible") is False)
h.eval(fw, "split.enabled = true")
check("frame window: shown with the split", h.eval(fw, "win.visible") is True)
h.eval(fw, "split.fullscreen = true")
check("frame window: hidden under a settled fullscreen window", wait_until(lambda: h.eval(fw, "win.visible") is False))

# ── Pixels: frame window + panel layer vs the unified panel ───────────
from panels_env import PanelsEnv  # noqa: E402

W, H = 800, 500
SCENE = """
import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.bar
import qs.modules.frame
import qs.modules.shell

Window {
    id: win
    width: %(W)d; height: %(H)d; visible: true; color: "black"
    // 0 unified panel; 1 frame window; 2 panel layer only (no frame)
    property int mode: 0
    property alias scene: scene
    ShellScreen { id: scr; name: "DP-1"; width: %(W)d; height: %(H)d }
    readonly property int frame: Config.bar.frameThickness

    QtObject {
        id: barProxy
        readonly property string barPosition: host.primary ? host.primary.barPosition : "top"
        readonly property bool reveal: true
        readonly property bool pinned: true
        readonly property bool hoverActive: false
        readonly property bool barHoverActive: false
        readonly property bool notchHoverActive: false
        readonly property bool notchOpen: false
        readonly property bool notchReveal: true
        readonly property var panelContainSides: host.containSides
        readonly property var panelZones: host.zones
    }
    Component.onCompleted: {
        Visibilities.barPanels = { "DP-1": barProxy };
        Visibilities.notchPanels = { "DP-1": barProxy };
    }

    // A notch attached to the frame's top inner edge and a dock attached to
    // its bottom one, as PanelShadows reads them (NotchContent / DockContent)
    Item {
        id: fakeNotch
        readonly property bool reveal: true
        readonly property int fadeDuration: 0
        readonly property int fadeEasing: Easing.Linear
        readonly property var silhouette: ({ "tl": 0, "tr": 0, "br": 18, "bl": 18, "attached": true, "cornerSize": 14, "position": "top", "surfaceAlpha": 1 })
        readonly property rect silhouetteRect: Qt.rect(win.width / 2 - 170, scene.holeTop, 340, 44)
        readonly property rect notificationPopupRect: Qt.rect(0, 0, 0, 0)
        readonly property real notificationPopupRadius: 0
        readonly property real notificationPopupAlpha: 1
    }
    Item {
        id: fakeDock
        readonly property bool reveal: true
        readonly property int fadeDuration: 0
        readonly property int fadeEasing: Easing.Linear
        readonly property var surface: ({ "shadowRadii": Qt.vector4d(16, 16, 0, 0), "isDefault": true, "cornerSize": 14, "position": "bottom", "fillAlpha": 1 })
        readonly property rect surfaceRect: Qt.rect(win.width / 2 - 150, scene.holeBottom - 58, 300, 58)
    }

    Item {
        id: scene
        anchors.fill: parent
        readonly property real holeTop: frameA.holeRect.y
        readonly property real holeBottom: frameA.holeRect.y + frameA.holeRect.height

        Rectangle {
            anchors.fill: parent
            visible: win.mode !== 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#7d8fb0" }
                GradientStop { position: 0.6; color: "#c9a27a" }
                GradientStop { position: 1; color: "#506a50" }
            }
        }
        // The frame window: its shadow under it
        Item {
            anchors.fill: parent
            visible: win.mode === 1
            FrameShapeShadow { frame: frameB }
            ScreenFrameContent { id: frameB; anchors.fill: parent; targetScreen: scr }
        }
        // The unified panel (mode 0) or its layer without the frame (mode 2)
        Item {
            anchors.fill: parent
            visible: win.mode !== 1
            PanelShadows {
                anchors.fill: parent
                z: 0
                frame: frameA
                frameElsewhere: win.mode === 2
                bars: host.bars
                notch: fakeNotch
                dock: fakeDock
            }
            ScreenFrameContent { id: frameA; anchors.fill: parent; targetScreen: scr; z: 1; visible: win.mode === 0 }
            PanelHost { id: host; anchors.fill: parent; screen: scr; z: 2 }
            StyledRect {
                z: 3; variant: "bg"; enableBorder: false; radius: 16
                x: fakeDock.surfaceRect.x; y: fakeDock.surfaceRect.y; width: fakeDock.surfaceRect.width; height: fakeDock.surfaceRect.height
            }
            StyledRect {
                z: 4; variant: "bg"; enableBorder: false; radius: 18
                x: fakeNotch.silhouetteRect.x; y: fakeNotch.silhouetteRect.y; width: fakeNotch.silhouetteRect.width; height: fakeNotch.silhouetteRect.height
            }
        }
    }
}
"""

LAYOUTS = {
    # A contained top bar (part of the frame's silhouette)
    "contained": {"frameEnabled": True, "frameThickness": 10, "containBar": True, "position": "top"},
    # A floating bar inside the frame on the left: its captured shadow
    # reaches the frame
    "floating": {"frameEnabled": True, "frameThickness": 10, "containBar": False, "position": "left"},
}


def grab_item(item):
    """The item rendered with its alpha (premultiplied ARGB)."""
    res = item.grabToImage()
    done = []
    res.ready.connect(lambda: done.append(True))
    wait_until(lambda: bool(done))
    return res.image().convertToFormat(QImage.Format.Format_ARGB32_Premultiplied)


def composite(below, above):
    out = below.copy()
    p = QPainter(out)
    p.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)
    p.drawImage(0, 0, above)
    p.end()
    return out


def rows(img):
    """The rows of an image as ARGB32 bytes (4 per pixel, no padding)."""
    img = img.convertToFormat(QImage.Format.Format_ARGB32)
    width, bpl = img.width() * 4, img.bytesPerLine()
    data = bytes(img.constBits())
    return [data[y * bpl:y * bpl + width] for y in range(img.height())]


def differing(ra, rb):
    """(x, y) of every pixel whose four bytes differ between two images."""
    out = set()
    for y, (la, lb) in enumerate(zip(ra, rb, strict=True)):
        if la == lb:
            continue
        out.update((x, y) for x in range(len(la) // 4) if la[x * 4:x * 4 + 4] != lb[x * 4:x * 4 + 4])
    return out


def diff(a, b, again, band, tol=2):
    """Pixels differing by more than `tol` per colour channel (composited
    8-bit premultiplied layers round by 1-2), split into those inside `band`
    (the contained bar's strip of the frame, see below) and the rest:
    {"band"|"rest": [count, worst channel difference, bounding box]}.
    Pixels that changed between two grabs of the same unified scene
    (`again`: a ticking clock) are left out and counted under "moving"."""
    pa, pb = rows(a), rows(b)
    moving = differing(pa, rows(again))
    hits = {"band": [], "rest": []}
    worst = {"band": 0, "rest": 0}
    for x, y in differing(pa, pb) - moving:
        delta = max(abs(pa[y][x * 4 + c] - pb[y][x * 4 + c]) for c in range(3))
        if delta <= tol:
            continue
        key = "band" if band.contains(x, y) else "rest"
        hits[key].append((x, y))
        worst[key] = max(worst[key], delta)
    out = {"moving": len(moving)}
    for key, points in hits.items():
        box = None
        if points:
            xs, ys = [q[0] for q in points], [q[1] for q in points]
            box = QRect(min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)
        out[key] = [len(points), worst[key], box]
    return out


def where(r):
    return f"{r[0]} px, worst {r[1]}/255" + (f", in {r[2].x()},{r[2].y()} {r[2].width()}x{r[2].height()}" if r[2] else "")


for lang in LANGUAGES:
    for name, bar in LAYOUTS.items():
        env = PanelsEnv(f"frame-split-{lang}-{name}", bar=bar, theme={"language": lang, "animDuration": 0})
        win = env.load(SCENE % {"W": W, "H": H})
        settle()
        pump(250)
        item = env.h.eval(win, "scene")
        env.h.eval(win, "mode = 0")
        settle()
        pump(40)
        unified = grab_item(item)
        env.h.eval(win, "mode = 1")
        settle()
        pump(40)
        frame_layer = grab_item(item)
        env.h.eval(win, "mode = 2")
        settle()
        pump(40)
        panel_layer = grab_item(item)
        env.h.eval(win, "mode = 0")
        settle()
        pump(40)
        unified_again = grab_item(item)
        split = composite(frame_layer, panel_layer)
        hole = json.loads(env.h.eval(win, "JSON.stringify({x: frameA.holeRect.x, y: frameA.holeRect.y})"))
        # The contained bar's strip: the frame between the screen edge and
        # the hole on the bar's side (top here)
        band = QRect(0, 0, W, int(hole["y"])) if name == "contained" else QRect()
        d = diff(unified, split, unified_again, band)
        frame_alpha = env.h.eval(win, "Number(frameA.fillAlpha).toFixed(2)")
        label = f"{lang} {name} (frame fill alpha {frame_alpha})"
        drawn = frame_layer.pixelColor(2, H // 2) != unified.pixelColor(W // 2, H // 2)
        check(f"{label}: frame drawn in the frame window", drawn)
        # Everywhere but the contained bar's text: only antialiased pixels
        # where a shadow meets the frame's rounded hole may differ, faintly
        check(f"{label}: split = unified but at the hole's antialiased edge", d["rest"][0] <= 200 and d["rest"][1] <= 8,
              f"{where(d['rest'])}; {d['moving']} px animate between grabs")
        if name == "contained":
            # Text drawn straight on the frame (no group box under it):
            # its antialiased (subpixel) edges blend differently over a
            # transparent window than over the frame in the same scene
            print(f"INFO {label}: contained bar strip differs in {where(d['band'])}")
        if SHOTS:
            Path(SHOTS).mkdir(parents=True, exist_ok=True)
            unified.save(f"{SHOTS}/{lang}-{name}-unified.png")
            split.save(f"{SHOTS}/{lang}-{name}-split.png")
            img = QImage(W, H, QImage.Format.Format_RGB32)
            img.fill(QColor("black"))
            for x, y in differing(rows(unified), rows(split)):
                img.setPixelColor(x, y, QColor("white"))
            img.save(f"{SHOTS}/{lang}-{name}-diff.png")
        win.close()

h.exit(0 if ok_all else 1)
