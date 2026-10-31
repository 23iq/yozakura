"""theme.lighting (modules/theme/Lighting.qml): with mode "off" the shell
shadow is exactly the theme's, nothing lantern-related exists and no timer
runs; fixed / sun modes move the shadow, light the top edge of surface
roots, and the lantern glows under a surface while a LanternScope ancestor
sees the pointer."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402

from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components
Window {
    width: 400; height: 300; visible: true
    function setLighting(mode, lantern, ms) {
        Lighting.latitude = 40.4;
        Lighting.longitude = -3.7;
        Lighting.overrideTime = ms;
        Config.theme.lighting = Object.assign({}, Config.theme.lighting, { mode: mode, lantern: lantern });
    }
    Item {
        anchors.fill: parent
        LanternScope {}
        StyledRect {
            objectName: "surface"
            x: 50; y: 50; width: 300; height: 200
            variant: "popup"
            glassSurface: "popups"
            enableShadow: true
            MouseArea { anchors.fill: parent; hoverEnabled: true }
        }
    }
}
"""

MORNING = 1793432400000  # 2026-10-31T07:40:00Z, Madrid: low sun in the east-south-east

env = KitEnv("lighting", overrides={"theme": {"language": "glass"}})
h = env.h
win = env.load(SCENE)
surface = h.find(win, "surface")
lantern = h.find(surface, "lantern")
assert lantern is not None

# Off (default): the theme shadow exactly, no clock, no lantern
assert h.eval(win, "Lighting.mode") == "off"
for k in ("XOffset", "YOffset", "Blur", "Opacity"):
    assert h.eval(win, f"Lighting.shadow{k} === Config.theme.shadow{k}"), k
assert h.eval(win, "Lighting.shadowColor === Qt.color(Config.resolveColor(Config.theme.shadowColor))")
assert h.eval(win, "Lighting.edgeStrength") == 0 and h.eval(win, "Lighting.edgeCenter") == 0.5
assert h.eval(win, "Lighting.clock.running") is False
assert lantern.property("active") is False

# Fixed: light from the top-left, shadow down-right, lit edge on the left
h.eval(win, "setLighting('fixed', 'off', 0)")
assert h.eval(win, "Lighting.shadowXOffset") > 0 and h.eval(win, "Lighting.shadowYOffset") > 0
assert h.eval(win, "Lighting.edgeCenter") < 0.5 and h.eval(win, "Lighting.edgeStrength") > 0
assert h.eval(win, "Lighting.clock.running") is False

# Sun in the morning: long shadow to the right, warm
h.eval(win, f"setLighting('sun', 'off', {MORNING})")
assert h.eval(win, "Lighting.shadowXOffset") >= 8, h.eval(win, "Lighting.shadowXOffset")
assert h.eval(win, "Lighting.warmth") > 0.5
assert h.eval(win, "Lighting.night") is False

# Lantern: always on, follows the pointer even over a hover-taking child
h.eval(win, "setLighting('sun', 'always', 0)")
assert lantern.property("active") is True
glow = lantern.property("item")
QTest.mouseMove(win, QPoint(120, 120))
QTest.qWait(30)
QTest.mouseMove(win, QPoint(150, 130))
QTest.qWait(400)
assert h.eval(glow, "scope !== null")
assert glow.property("tracking") is True
spot = glow.property("spot")
assert abs(spot.x() - 100) < 1 and abs(spot.y() - 80) < 1, spot
assert glow.property("opacity") > 0.9

h.eval(win, "setLighting('off', 'off', 0)")
assert lantern.property("active") is False

print("lighting: ok")
h.exit(0)
