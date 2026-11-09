"""Media seek bar (modules/components/PositionSlider.qml, on the kit
LineSlider): it follows the player while idle, a drag seeks once on release
to the dragged position (not back to where the player was), the wheel is left
to the surface under it, the playhead knob always shows, and a player that cannot seek is never written."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.components
Window {
    width: 420; height: 80; visible: true
    QtObject {
        id: player
        objectName: "player"
        property int playbackState: 1
        property real length: 200
        property real position: 50
        property bool canSeek: true
        property int seeks: 0
        onPositionChanged: seeks++
    }
    PositionSlider { objectName: "seek"; x: 10; y: 30; width: 400; player: player }
}"""

env = KitEnv("position-slider")
env.h.module("Quickshell.Services.Mpris", {
    "MprisPlaybackState": "QtObject { readonly property int Stopped: 0; readonly property int Playing: 1; "
                          "readonly property int Paused: 2 }"})
h = env.h
win = env.load(SCENE)
seek = h.find(win, "seek")
player = h.find(win, "player")
QTest.qWait(50)

assert abs(seek.property("value") - 0.25) < 1e-6, seek.property("value")
player.setProperty("position", 100)
assert abs(seek.property("value") - 0.5) < 1e-6, "follows the player while idle"
assert seek.property("wheelEnabled") is False, "the wheel is left to the surface under it"
assert seek.property("hovered") is False and h.eval(h.find(seek, "lineSliderKnob"), "scale") == 1, \
    "the playhead knob shows without hover (alwaysShowKnob)"

player.setProperty("seeks", 0)
origin = h.eval(seek, "mapToItem(null, 0, height / 2)")
x0, y = int(origin.x()), int(origin.y())
area = h.eval(seek, "width")
QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + int(area * 0.7), y))
for f in (0.72, 0.76, 0.8):
    QTest.mouseMove(win, QPoint(x0 + int(area * f), y))
    QTest.qWait(10)
# A position tick from the player while dragging does not move the knob.
player.setProperty("position", 102)
player.setProperty("seeks", 0)
assert seek.property("value") > 0.7, "dragging keeps the dragged value"
QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + int(area * 0.8), y))
QTest.qWait(20)
assert player.property("seeks") == 1, ("one seek on release", player.property("seeks"))
pos = player.property("position")
assert 150 < pos < 170, ("seeks to the dragged position, not back", pos)
assert abs(seek.property("value") - pos / 200) < 1e-6, "follows the player again after the drag"

# A player that cannot seek is never written.
player.setProperty("canSeek", False)
player.setProperty("seeks", 0)
QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + int(area * 0.2), y))
QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + int(area * 0.2), y))
QTest.qWait(20)
assert player.property("seeks") == 0, "no seek without canSeek"

print("position-slider: ok")
