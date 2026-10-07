"""Notch activity segments under a real pointer (offscreen): moving the
pointer onto the downloads segment of the resting notch opens the transfers
panel, onto the privacy segment the privacy panel.

Regression: the header's side zones (IslandHeader leading/trailing
HoverHandler items) were stacked above the segments and took the hover from
them, so `hoverTrigger` stayed "" and no panel ever opened by hover (the
older tests forced `hoverOverride` and never saw it)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib import headless  # noqa: E402,F401
from island_env import IslandEnv  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = IslandEnv("notch-segment-hover", notch={"style": "pill", "expandOn": "hover"}, theme={"language": "ink"})
win = env.scene()
h = env.h
h.eval(win, "seed()")
QTest.qWait(300)
header = h.find(win, "islandHeader")
controller = h.find(win, "panelController")


def centre(segment: str) -> QPoint:
    xy = h.eval(header, f"(function(){{ var s = {segment}; var q = s.mapToItem(null, s.width / 2, s.height / 2); return q.x + ',' + q.y; }})()")
    x, y = (float(v) for v in xy.split(","))
    return QPoint(round(x), round(y))


def rest_on(segment: str) -> None:
    p = centre(segment)
    QTest.mouseMove(win, p)
    QTest.qWait(30)
    QTest.mouseMove(win, p + QPoint(1, 0))
    QTest.qWait(300)


assert h.eval(header, "tasksSegment.shown") and h.eval(header, "trailingSegment.shown")
rest_on("tasksSegment")
assert h.eval(header, "hoverTrigger") == "tasks" or h.eval(controller, "openPanel") == "transfers", h.eval(header, "hoverTrigger")
assert h.eval(controller, "openPanel") == "transfers", "the downloads segment opens the transfers panel under a real pointer"

QTest.mouseMove(win, QPoint(5, 500))
QTest.qWait(500)
assert h.eval(controller, "openPanel") == "", "leaving the notch closes it"

rest_on("trailingSegment")
assert h.eval(controller, "openPanel") == "privacy", "the privacy segment opens the privacy panel"

print("notch segment hover: real pointer opens the transfers and privacy panels")
h.exit(0)
