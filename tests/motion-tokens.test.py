"""Motion tokens follow Config.animDuration, stay inside the budget and are 0 at 0."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("motion-tokens")
h.singleton("Quickshell", "Quickshell", "QtObject {}")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 300
    property bool motionDrivesShell: true
    property var motionProfile: ({ shell: { easing: "InOutSine" } })
}""")
h.copy("config/motion/MotionBudget.js")
h.copy("modules/theme/Motion.qml", strip_singleton=True, siblings=False, replace={
    "Singleton {": "QtObject {",
    "import Quickshell\n": "",
    "../../config/motion/MotionBudget.js": "MotionBudget.js",
})
root = h.load('Item { property QtObject m: Motion { objectName: "m" } }', auto_stub=False)
m = h.find(root, "m")
cfg = h.engine.singletonInstance("qs.config", "Config")


def ev(expr):
    return h.eval(m, expr)


# InOutSine profile easing -> enter/morph decelerate, exit keeps it.
assert ev("enter.duration") == 260, ev("enter.duration")
assert ev("exit.duration") == 180
assert ev("morph.duration") == 360
assert ev("emphasis.duration") == 450
assert ev("delay") <= 40 and ev("palette") <= 600
assert ev("enter.easing") == ev("Easing.OutSine"), "enter easing must be Out"
assert ev("exit.easing") == ev("Easing.InOutSine")
assert ev("enter.overshoot") == 1.0

cfg.setProperty("animDuration", 100)
assert ev("enter.duration") == 87 and ev("exit.duration") == 60, (ev("enter.duration"), ev("exit.duration"))

cfg.setProperty("animDuration", 0)
for k in ("enter", "exit", "morph", "emphasis"):
    assert ev(k + ".duration") == 0, k
assert ev("delay") == 0 and ev("palette") == 0

cfg.setProperty("motionProfile", {"shell": {"easing": "OutBack"}})
cfg.setProperty("animDuration", 300)
assert ev("enter.easing") == ev("Easing.OutBack") and ev("enter.overshoot") == 1.2
print("ok")
