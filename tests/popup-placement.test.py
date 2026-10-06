"""BarPopup placement and motion, offscreen: with the bar on each of the four
edges the popup opens away from the bar, never overlaps it, stays fully on
screen (also for anchors near a corner, where it is clamped) and opens/closes
instantly with animDuration 0; with motion on it animates in and hides only
after the exit motion. The `tab` popup corners face the anchor."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import panels_stubs as stubs  # noqa: E402
from panels_env import PanelsEnv  # noqa: E402
from qmlharness import brand_qml  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

W, H, BAR = 1600, 900, 40
CW, CH = 300, 200
failures: list[str] = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


SCENE = f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.components
Window {{
    id: w
    width: {W}; height: {H}; visible: true
    property string edge: "top"
    // anchor position along the bar: 0..1
    property real along: 0.5
    readonly property bool vertical: edge === "left" || edge === "right"
    Item {{
        id: barStrip
        objectName: "bar"
        x: w.edge === "right" ? w.width - {BAR} : 0
        y: w.edge === "bottom" ? w.height - {BAR} : 0
        width: w.vertical ? {BAR} : w.width
        height: w.vertical ? w.height : {BAR}
        Item {{
            id: anchorBox
            objectName: "anchor"
            width: 30; height: 30
            x: w.vertical ? 5 : Math.max(0, Math.min(barStrip.width - width, barStrip.width * w.along - width / 2))
            y: w.vertical ? Math.max(0, Math.min(barStrip.height - height, barStrip.height * w.along - height / 2)) : 5
        }}
    }}
    BarPopup {{
        id: popup
        objectName: "popup"
        anchorItem: anchorBox
        bar: ({{ barPosition: w.edge }})
        contentWidth: {CW}; contentHeight: {CH}
    }}
}}"""


def run(anim_ms: int, corners: str = "round"):
    env = PanelsEnv("popup-placement", theme={"animDuration": anim_ms, "shape": {"corners": corners, "popupCorners": "", "cutSize": 10}})
    win = env.load(SCENE)
    QTest.qWait(50)
    return env, win


def content_rect(env, win):
    motion = env.h.find(win, "popupMotion")
    x = env.h.eval(motion, "mapToItem(null, 0, 0).x")
    y = env.h.eval(motion, "mapToItem(null, 0, 0).y")
    return x, y, env.h.eval(motion, "width"), env.h.eval(motion, "height"), motion


def overlaps(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


AWAY = {"top": "down", "bottom": "up", "left": "right", "right": "left"}
FACING = {"top": "top", "bottom": "bottom", "left": "left", "right": "right"}

# animDuration 0: instant, every edge, centered and near-corner anchors
env, win = run(0, corners="tab")
popup = env.h.find(win, "popup")
for edge in ["top", "bottom", "left", "right"]:
    for along in [0.5, 0.0, 1.0]:
        tag = f"{edge}@{along}"
        env.h.eval(win, f'w.edge = "{edge}"; w.along = {along}')
        QTest.qWait(20)
        env.h.eval(popup, "open()")
        check(env.h.eval(popup, "visible") is True, f"{tag}: opens")
        x, y, cw, ch, motion = content_rect(env, win)
        check((cw, ch) == (CW, CH), f"{tag}: content size {cw}x{ch}")
        check(env.h.eval(motion, "progress") == 1 and env.h.eval(motion, "opacity") == 1,
              f"{tag}: animDuration 0 opens instantly")
        check(env.h.eval(popup, "placement.dir") == AWAY[edge], f"{tag}: opens away from the bar")
        check(0 <= x and 0 <= y and x + cw <= W and y + ch <= H, f"{tag}: on screen ({x},{y})")
        bar = (env.h.eval(win, "barStrip.x"), env.h.eval(win, "barStrip.y"),
               env.h.eval(win, "barStrip.width"), env.h.eval(win, "barStrip.height"))
        check(not overlaps((x, y, cw, ch), bar), f"{tag}: stays off the bar ({x},{y})")
        gap = env.h.eval(popup, "gap")
        if along == 0.5:  # centered anchors sit exactly `gap` from the anchor
            near = {"top": y - (5 + 30), "bottom": (H - BAR + 5) - (y + ch),
                    "left": x - (5 + 30), "right": (W - BAR + 5) - (x + cw)}[edge]
            check(near == gap, f"{tag}: {near}px from the anchor, want {gap}")
        check(env.h.eval(motion, "anchorEdge") == FACING[edge], f"{tag}: tab corners face the bar")
        env.h.eval(popup, "close()")
        check(env.h.eval(popup, "visible") is False, f"{tag}: animDuration 0 closes instantly")

# motion on: animates in, hides only after the exit motion
env2, win2 = run(300)
popup2 = env2.h.find(win2, "popup")
env2.h.eval(win2, 'w.edge = "left"; w.along = 0.5')
env2.h.eval(popup2, "open()")
motion2 = env2.h.find(win2, "popupMotion")
check(env2.h.eval(motion2, "running") is True, "motion: the entry animates")
QTest.qWait(600)
check(env2.h.eval(motion2, "progress") == 1, "motion: settles at rest")
env2.h.eval(popup2, "close()")
check(env2.h.eval(popup2, "visible") is True, "motion: still visible during the exit")
QTest.qWait(600)
check(env2.h.eval(popup2, "visible") is False, "motion: hidden after the exit")
# reopen while closing goes straight back in
env2.h.eval(popup2, "open()")
env2.h.eval(popup2, "close()")
env2.h.eval(popup2, "open()")
QTest.qWait(600)
check(env2.h.eval(popup2, "visible") is True and env2.h.eval(motion2, "progress") == 1, "motion: reopen while closing")

# Cursor context menu (ContextMenu + OptionsMenu): below the cursor, flipped
# above and clamped near the screen's bottom-right corner, instant with
# animDuration 0.
env3 = PanelsEnv("popup-placement-menu", theme={"animDuration": 0})
env3.h.module("qs.modules.globals", {"GlobalStates": stubs.GLOBAL_STATES, "Brand": brand_qml()})
# Layer-shell attached properties and edge anchors have no offscreen stand-in
_cm = env3.root / "qs/modules/components/ContextMenu.qml"
_text = re.sub(r"\n    anchors \{[^}]*\}", "", _cm.read_text(), count=1)
_cm.write_text("\n".join(ln for ln in _text.splitlines() if "WlrLayershell" not in ln))
win3 = env3.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.components
Window {{
    width: {W}; height: {H}; visible: true
    ContextMenu {{ id: cm; objectName: "cm"; anchors.fill: parent }}
}}""")
cm = env3.h.find(win3, "cm")
QTest.qWait(50)
env3.h.eval(cm, 'openCustomMenu([{text: "One"}, {text: "Two"}, {text: "Three"}])')
menu = env3.h.find(win3, "contextOptionsMenu")
for (cx, cy, want) in [(100, 100, "down"), (W - 5, H - 5, "up")]:
    env3.h.eval(cm, f"placeAt({cx}, {cy})")
    QTest.qWait(50)
    mx, my = env3.h.eval(menu, "x"), env3.h.eval(menu, "y")
    mw, mh = env3.h.eval(menu, "width"), env3.h.eval(menu, "implicitHeight")
    check(env3.h.eval(menu, "openDir") == want, f"menu at ({cx},{cy}) opens {want}")
    check(0 <= mx and mx + mw <= W and 0 <= my and my + mh <= H, f"menu at ({cx},{cy}) on screen ({mx},{my})")
    check(env3.h.eval(menu, "opacity") == 1, f"menu at ({cx},{cy}) opens instantly with animDuration 0")
check(env3.h.eval(menu, "y") < H - 5 - env3.h.eval(menu, "implicitHeight") + 1, "flipped menu sits above the cursor")
env3.h.eval(cm, "close()")

print("popup-placement:", "OK" if not failures else f"{len(failures)} failure(s)")
sys.exit(1 if failures else 0)
