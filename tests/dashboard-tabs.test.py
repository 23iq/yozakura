"""The dashboard's tool tabs offscreen (tests/lib/dashtabs_env.py), built
from the kit.

Metrics: one meter per resource (CPU, RAM, each GPU, each disk) in its
series colour with its value and temperature, the interval stepper (100 ms
steps, never under 100, saved), the zoom slider (saved, rounded) and the
chart painting.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.dashtabs_env import DashTabsEnv  # noqa: E402
from lib.settings_env import DEFAULT_PALETTE  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

# The series colours come from the palette's named colours.
SERIES = {"red": "#ff5555", "cyan": "#55ffff", "yellow": "#ffff55", "green": "#55ff55", "blue": "#5555ff",
          "magenta": "#ff55ff"}
env = DashTabsEnv("dashboard-tabs", palette={**DEFAULT_PALETTE, **SERIES})
h = env.h


def check(cond, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def ev(obj, expr: str):
    return h.eval(obj, expr)


def items(root, name: str) -> list:
    """Every item named `name` in the visual tree (Repeater delegates included)."""
    out, stack = [], [root]
    while stack:
        it = stack.pop()
        if it.objectName() == name:
            out.append(it)
        stack.extend(it.childItems())
    return out


def item(root, name: str):
    found = items(root, name)
    check(len(found) > 0, "item " + name)
    return found[0]


# --- metrics
win = env.scene("MetricsTab {}", 860, 430)
QTest.qWait(150)
tab = win.findChild(QQuickItem, "view")
lines = items(tab, "resourceLine")
check(len(lines) == 6, "a meter per CPU, RAM, GPU and disk (%d)" % len(lines))
values = sorted(round(ev(x, "value"), 2) for x in lines)
check(values == [0.12, 0.23, 0.37, 0.41, 0.48, 0.72], "meter values %s" % values)
colors = sorted(ev(x, "fillColor.toString()") for x in lines)
want = sorted(SERIES[k] for k in ("red", "cyan", "red", "green", "yellow", "yellow"))
check(colors == want, "series colours (CPU red, RAM cyan, GPUs by vendor, disks yellow): %s" % colors)

text = item(tab, "intervalText")
check(ev(text, "text") == "2000ms", "interval shown")
ev(item(tab, "intervalUp"), "clicked()")
check(ev(text, "text") == "2100ms", "interval steps up by 100 ms")
check(ev(text, "StateService.get('metricsRefreshInterval', 0)") == 2100, "interval saved")
for _ in range(30):
    ev(item(tab, "intervalDown"), "clicked()")
check(ev(text, "text") == "100ms", "interval never under 100 ms")

slider = item(tab, "zoomSlider")
check(abs(ev(slider, "value") - 1) < 1e-6, "zoom slider at the default zoom")
ev(slider, "setFraction(0.5)")
check(abs(ev(tab, "chartZoom") - 1.6) < 1e-6, "zoom from the slider, one decimal (%s)" % ev(tab, "chartZoom"))
check(abs(ev(text, "StateService.get('metricsChartZoom', 0)") - 1.6) < 1e-6, "zoom saved")

chart = item(tab, "metricsChart")
check(ev(chart, "width") > 300 and ev(chart, "height") > 200, "chart fills the right column")
win.close()

print("dashboard-tabs: ok")
h.exit(0)
