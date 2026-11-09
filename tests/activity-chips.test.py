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
from waits import pump, settle, wait_stable, wait_until  # noqa: E402

BAR = {"frameEnabled": False, "containBar": False, "pinnedOnStartup": True, "panels": [{
    "id": "main", "edge": "top", "style": "dock-like", "align": "center",
    "groups": {"start": ["launcher", "workspaces"], "end": ["controls", "clock"]}}]}

env = IslandEnv("activity-chips", bar=BAR, notch={"style": "pill", "position": "top"}, theme={"language": "ink"})
win = PanelsEnv.scene(env, 1400, 800, windows=False)
h = env.h
svc = h.load("import QtQuick\nimport qs.modules.theme\nimport qs.modules.services.activities\nQtObject {}")
settle(3)


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


def move(p: QPoint, until=None, wait: int = 0) -> None:
    """Pointer to `p`; then wait for `until()` or, for a deliberate hold, `wait` ms."""
    QTest.mouseMove(win, p)
    settle(1)
    QTest.mouseMove(win, p + QPoint(1, 0))
    if until is not None:
        wait_until(until)
    if wait:
        pump(wait)


def is_open():
    return h.eval(popup, "isOpen")


def closed():
    return not h.eval(popup, "isOpen") and not h.eval(popup, "visible")


def away(until=None):
    move(QPoint(5, 700), until or closed)


assert find(win.contentItem(), "activities") is None, "presentation notch: no chips module"
h.eval(svc, "ActivityService.presentation = 'bar'")
h.eval(svc, f"ActivityService.transfers = {TRANSFERS}")
h.eval(svc, f"ActivityService.activities = {ACTIVITIES}.filter(a => a.id === 'downloads' || a.id === 'privacy:mic')")
wait_until(lambda: find(win.contentItem(), "activities") is not None
           and h.eval(find(win.contentItem(), "activities"), "!collapsed && shownLength > 20"))
module = find(win.contentItem(), "activities")
assert module is not None, "presentation bar: the end group gains the chips"
assert not h.eval(module, "collapsed") and h.eval(module, "shownLength") > 20
popup = find(win.contentItem(), "activityChipPopup")
chip = find(win.contentItem(), "activityChip:downloads")
assert chip is not None
wait_stable(lambda: (h.eval(module, "shownLength"), centre(chip)))  # chips slid in

move(centre(chip), is_open)
assert h.eval(popup, "isOpen"), "resting on the chip opens its popup"
assert h.eval(popup, "panelId") == "transfers"
assert not h.eval(popup, "claimFocus"), "hover-opened: no focus grab"

# Progress refreshes keep activity ids but replace the Repeater's chip
# delegates. The old delegate must not leave its hover behind.
h.eval(svc, f"ActivityService.activities = {ACTIVITIES}.filter(a => a.id === 'downloads' || a.id === 'privacy:mic').map(a => Object.assign({{}}, a, {{progress: 0.6}}))")
settle(3)
chip = find(win.contentItem(), "activityChip:downloads")

# Into the popup: stays open past the collapse delay
inside = popup.mapToItem(None, popup.width() / 2, popup.height() / 2)
move(QPoint(round(inside.x()), round(inside.y())), wait=h.eval(popup, "Config.notch.hoverCollapseDelay") + 150)
assert h.eval(popup, "isOpen"), "chip -> popup keeps it open"

away()
assert not h.eval(popup, "isOpen"), "leaving chip and popup closes it"
assert not h.eval(popup, "visible"), "the closed popup is unmapped"

# The surface may remain mapped for its exit animation, or until the
# fallback timer runs if rendering stops. It must stop taking input as
# soon as the pointer's collapse delay closes it.
move(centre(chip), is_open)
assert h.eval(popup, "isOpen")
move(QPoint(5, 700), wait=h.eval(module, "Config.notch.hoverCollapseDelay") + 20)
assert not h.eval(popup, "isOpen"), "leaving releases the popup before its exit finishes"
assert h.eval(popup, "visible"), "the exit surface is still mapped when input is released"
assert h.eval(popup, "mask !== null && mask.item === null && mask.regions.length === 0"), \
    "closing activity popup has an empty input region, even while mapped"
wait_until(closed)
move(centre(chip), lambda: is_open() and h.eval(popup, "mask === null"))
assert h.eval(popup, "isOpen") and h.eval(popup, "mask === null"), "reopening restores popup input"
away()

# Click pins, leaving keeps it, a second click unpins
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, centre(chip))
wait_until(lambda: is_open() and h.eval(module, "pinned") and h.eval(popup, "claimFocus"))
assert h.eval(popup, "isOpen") and h.eval(module, "pinned") and h.eval(popup, "claimFocus")
move(QPoint(5, 700), wait=h.eval(popup, "Config.notch.hoverCollapseDelay") + 150)
assert h.eval(popup, "isOpen"), "pinned: leaving keeps it"
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, centre(chip))
wait_until(lambda: not is_open() and not h.eval(module, "pinned"))
assert not h.eval(popup, "isOpen") and not h.eval(module, "pinned")

# The privacy chip opens the privacy panel
mic = find(win.contentItem(), "activityChip:privacy:mic")
move(centre(mic), lambda: is_open() and h.eval(popup, "panelId") == "privacy")
assert h.eval(popup, "isOpen") and h.eval(popup, "panelId") == "privacy"
away()

# The hovered activity ends under the pointer: its chip is gone, so is the
# hover it held; the popup closes, keeps an anchor and a later activity
# never opens it by itself
move(centre(find(win.contentItem(), "activityChip:downloads")), is_open)
assert h.eval(popup, "isOpen")
h.eval(svc, "ActivityService.activities = []")
h.eval(svc, "ActivityService.transfers = []")
wait_until(closed)
assert not h.eval(popup, "isOpen") and not h.eval(popup, "visible"), "ended activity closes its popup"
assert h.eval(module, "hoverChip") == "" and not h.eval(module, "held"), "no hover left on a removed chip"
assert not h.eval(popup, "anchorItem === null"), "the popup never loses its anchor"
move(QPoint(5, 700))
h.eval(svc, f"ActivityService.transfers = {TRANSFERS}")
h.eval(svc, f"ActivityService.activities = {ACTIVITIES}.filter(a => a.id === 'downloads')")
wait_until(lambda: find(win.contentItem(), "activityChip:downloads") is not None)
# Give a wrongly opening popup its hover-expand delay and more.
pump(h.eval(popup, "Config.notch.hoverExpandDelay") + 300)
assert not h.eval(popup, "isOpen"), "a new activity does not open the popup without the pointer"

h.eval(svc, "ActivityService.activities = []")
wait_until(lambda: h.eval(module, "collapsed"))
assert h.eval(module, "collapsed"), "no activities: the module folds away"

print("activity chips: bar presence, hover popup, progress refresh, chip->popup hold, input release, pin, privacy panel, ended under pointer, fold")
h.exit(0)
