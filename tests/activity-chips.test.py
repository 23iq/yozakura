"""Live activity chips in the bar (modules/bar/modules/ActivityChips.qml)
offscreen, real bar + real pointer: with ActivityService.presentation "bar"
the panel on the notch edge leads its end group with the chips; resting on
the downloads chip opens its TransfersPanel popup, moving into the popup
keeps it, leaving closes it after notch.hoverCollapseDelay, a click pins it
(and unpins); without activities the module folds away."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib import headless  # noqa: E402,F401
from island_env import ACTIVITIES, TRANSFERS, IslandEnv  # noqa: E402
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

BAR = {"frameEnabled": False, "containBar": False, "pinnedOnStartup": True, "panels": [{
    "id": "main", "edge": "top", "style": "dock-like", "align": "center",
    "groups": {"start": ["launcher", "workspaces"], "end": ["controls", "clock"]}}]}

env = IslandEnv("activity-chips", bar=BAR, notch={"style": "pill", "position": "top"}, theme={"language": "ink"})
win = PanelsEnv.scene(env, 1400, 800, windows=False)
h = env.h
svc = h.load("import QtQuick\nimport qs.modules.theme\nimport qs.modules.services.activities\nQtObject {}")
QTest.qWait(300)


def find(item, name):
    if item.objectName() == name:
        return item
    for c in item.childItems():
        hit = find(c, name)
        if hit is not None:
            return hit
    return None


def centre(item) -> QPoint:
    p = item.mapToItem(None, item.width() / 2, item.height() / 2)
    return QPoint(round(p.x()), round(p.y()))


def move(p: QPoint, wait: int = 300) -> None:
    QTest.mouseMove(win, p)
    QTest.qWait(20)
    QTest.mouseMove(win, p + QPoint(1, 0))
    QTest.qWait(wait)


assert find(win.contentItem(), "activities") is None, "presentation notch: no chips module"
h.eval(svc, "ActivityService.presentation = 'bar'")
h.eval(svc, f"ActivityService.transfers = {TRANSFERS}")
h.eval(svc, f"ActivityService.activities = {ACTIVITIES}.filter(a => a.id === 'downloads' || a.id === 'privacy:mic')")
QTest.qWait(600)
module = find(win.contentItem(), "activities")
assert module is not None, "presentation bar: the end group gains the chips"
assert not h.eval(module, "collapsed") and h.eval(module, "shownLength") > 20
popup = find(win.contentItem(), "activityChipPopup")
chip = find(win.contentItem(), "activityChip:downloads")
assert chip is not None

move(centre(chip))
assert h.eval(popup, "isOpen"), "resting on the chip opens its popup"
assert h.eval(popup, "panelId") == "transfers"
assert not h.eval(popup, "claimFocus"), "hover-opened: no focus grab"

# Into the popup: stays open past the collapse delay
inside = popup.mapToItem(None, popup.width() / 2, popup.height() / 2)
move(QPoint(round(inside.x()), round(inside.y())), 500)
assert h.eval(popup, "isOpen"), "chip -> popup keeps it open"

move(QPoint(5, 700), 600)
assert not h.eval(popup, "isOpen"), "leaving chip and popup closes it"

# Click pins, leaving keeps it, a second click unpins
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, centre(chip))
QTest.qWait(100)
assert h.eval(popup, "isOpen") and h.eval(module, "pinned") and h.eval(popup, "claimFocus")
move(QPoint(5, 700), 600)
assert h.eval(popup, "isOpen"), "pinned: leaving keeps it"
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, centre(chip))
QTest.qWait(300)
assert not h.eval(popup, "isOpen") and not h.eval(module, "pinned")

# The privacy chip opens the privacy panel
mic = find(win.contentItem(), "activityChip:privacy:mic")
move(centre(mic))
assert h.eval(popup, "isOpen") and h.eval(popup, "panelId") == "privacy"
move(QPoint(5, 700), 600)

h.eval(svc, "ActivityService.activities = []")
QTest.qWait(800)
assert h.eval(module, "collapsed"), "no activities: the module folds away"

print("activity chips: bar presence, hover popup, chip->popup hold, pin, privacy panel, fold")
h.exit(0)
