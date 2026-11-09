"""Small kit-built pieces of the shell surfaces: the overview's WorkspaceRing
(accent on the active workspace, outline on a drop target), the capture
tools' CaptureHighlight (accent outline + wash only while lit) and the
dock's DockPinButton (32 px, accent while pinned, its glyph and tooltip follow)."""
import functools
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components.kit
Window {
    width: 300; height: 300; visible: true
    property int toggles: 0
    Column {
        WorkspaceRing { objectName: "ring"; width: 160; height: 90 }
        CaptureHighlight { objectName: "hl"; width: 100; height: 60; lit: false }
        DockPinButton { objectName: "pin"; onToggled: { pinned = !pinned; parent.Window.window.toggles++ } }
    }
}"""

FAILED = []


def check(cond, msg):
    if not cond:
        print("FAIL:", msg)
        FAILED.append(msg)


for lang in ("ink", "glass"):
    env = KitEnv(f"shell-kit-pieces-{lang}", overrides={"theme": {"language": lang}})
    h = env.h
    for rel in ("modules/widgets/overview/WorkspaceRing.qml", "modules/tools/CaptureHighlight.qml",
                "modules/dock/DockPinButton.qml"):
        h.copy(rel, siblings=False)
    win = env.load(SCENE)
    get = functools.partial(h.find, win)
    ev = functools.partial(h.eval, win)
    color = functools.partial(lambda hh, o, p: hh.eval(o, f"{p}.toString()"), h)

    ring = get("ring")
    check(h.eval(ring, "border.width") == 0, f"{lang}: an idle workspace has no ring")
    check(h.eval(ring, "radius") == ev('Look.radius("box")'), f"{lang}: the ring takes the box radius")
    ring.setProperty("target", True)
    check(h.eval(ring, "border.width") > 0 and color(ring, "border.color") == ev("Colors.outline.toString()"),
          f"{lang}: a drop target is outlined in the outline ink")
    ring.setProperty("active", True)
    check(color(ring, "border.color") == ev("Type.accent.toString()"), f"{lang}: the active workspace takes the accent")

    hl = get("hl")
    check(h.eval(hl, "border.color.a") == 0 and h.eval(hl, "children[0].opacity") == 0, f"{lang}: an unlit target is clear")
    hl.setProperty("lit", True)
    check(color(hl, "border.color") == ev("Type.accent.toString()"), f"{lang}: a lit target has the accent outline")
    check(abs(h.eval(hl, "children[0].opacity") - 0.2) < 1e-6, f"{lang}: a lit target has the accent wash")

    pin = get("pin")
    check(pin.property("active") is False and pin.property("icon") == ev("Icons.unpin"), f"{lang}: unpinned look")
    check(h.eval(pin, "width") == ev("Space.chip") == 32, f"{lang}: the dock keeps its 32 px buttons")
    win.requestActivate()
    QTest.qWait(30)
    px, py = json.loads(h.eval(pin, "(function () { var p = mapToItem(null, width / 2, height / 2); return JSON.stringify([p.x, p.y]); })()"))
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, QPoint(int(px), int(py)))
    check(win.property("toggles") == 1, f"{lang}: a click toggles the pin")
    check(pin.property("active") is True and pin.property("icon") == ev("Icons.pin"), f"{lang}: pinned look")
    check(pin.property("tooltip") != "", f"{lang}: the pin explains itself")
    win.close()

if FAILED:
    sys.exit(1)
print("shell-kit-pieces: ok")
