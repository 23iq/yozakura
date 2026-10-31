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


# InOutSine profile easing -> enter/morph decelerate (soft OutSine becomes
# OutCubic), exit accelerates away and is shorter than enter.
assert ev("enter.duration") == 220, ev("enter.duration")
assert ev("exit.duration") == 160
assert ev("exit.duration") < ev("enter.duration")
assert ev("morph.duration") == 280
assert ev("emphasis.duration") == 360
assert ev("micro.duration") <= 120 and ev("glide.duration") <= 220
assert ev("delay") <= 40 and ev("palette") <= 600
assert ev("enter.easing") == ev("Easing.OutCubic"), "enter easing must be a crisp Out"
assert ev("morph.easing") == ev("Easing.OutCubic")
assert ev("exit.easing") == ev("Easing.InQuad")
assert ev("enter.overshoot") == 1.0
assert ev("stagger(1)") == ev("delay") and ev("stagger(50)") <= 120

cfg.setProperty("animDuration", 100)
assert ev("enter.duration") == 90 and ev("exit.duration") == 62, (ev("enter.duration"), ev("exit.duration"))

cfg.setProperty("animDuration", 0)
for k in ("enter", "exit", "morph", "emphasis", "micro", "glide", "spring"):
    assert ev(k + ".duration") == 0, k
assert ev("delay") == 0 and ev("palette") == 0 and ev("stagger(3)") == 0

# A bouncy profile: panels never overshoot, emphasis and the press spring do.
cfg.setProperty("motionProfile", {"shell": {"easing": "OutBack"}})
cfg.setProperty("animDuration", 300)
assert ev("enter.easing") == ev("Easing.OutQuart") and ev("enter.overshoot") == 1.0
assert ev("glide.easing") == ev("Easing.OutQuart") and ev("morph.overshoot") == 1.0
assert ev("emphasis.easing") == ev("Easing.OutBack") and ev("emphasis.overshoot") == 1.2
assert ev("spring.easing") == ev("Easing.OutBack")
print("ok")
