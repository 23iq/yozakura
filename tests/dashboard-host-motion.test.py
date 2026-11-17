"""Dashboard motion by host: on the notch the dashboard fades and scales
itself (NotchAnimationBehavior, render-thread Animators); in the spotlight /
side sheet (HostedSurfaces) the host's frame animates it and the view has
no motion of its own (`ownMotion: false`). There the Animators misfired:
the view is built off any window (WarmLoader) and then shown inside the
frame's layer (its shadow), which missed their last frames, so the first
opens stayed half faded until something repainted."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]

# the spotlight / sheet owner builds its dashboard without motion of its own
hosted = (REPO / "modules/shell/hosts/HostedSurfaces.qml").read_text()
block = re.search(r"DashboardView \{(.*?)\}", hosted, re.S).group(1)
assert re.search(r"ownMotion:\s*false", block), "HostedSurfaces: DashboardView { ownMotion: false }"
notch = (REPO / "modules/shell/hosts/NotchHostedSurfaces.qml").read_text()
assert "ownMotion" not in notch, "the notch keeps the dashboard's own motion"

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.notch
Window {
    width: 200; height: 200; visible: true
    NotchAnimationBehavior { objectName: "own"; width: 50; height: 50 }
    NotchAnimationBehavior { objectName: "hosted"; ownMotion: false; width: 50; height: 50 }
}"""

env = KitEnv("dashboard-host-motion")
h = env.h
win = env.load(SCENE)
own = h.find(win, "own")
hosted_item = h.find(win, "hosted")

# hidden: the notch view is faded and shrunk, the hosted one only hidden
assert own.property("opacity") == 0 and own.property("scale") == 0.8
assert not hosted_item.property("visible")
assert hosted_item.property("opacity") == 1 and hosted_item.property("scale") == 1, \
    "off the notch the view never fades or scales itself"

for item in (own, hosted_item):
    item.setProperty("isVisible", True)
QTest.qWait(20)
assert hosted_item.property("visible")
assert hosted_item.property("opacity") == 1 and hosted_item.property("scale") == 1, \
    "shown off the notch at full opacity and size at once (nothing for the host's layer to miss)"

print("dashboard-host-motion: ok")
