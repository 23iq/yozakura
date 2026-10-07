"""Bar panels engine, offscreen: legacy parity, multi-panel reservations,
autohide, screen filters, every style loading on every edge, shared pin."""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

STYLES = {
    "classic": ["top", "bottom", "left", "right"], "islands": ["top", "left"], "menubar": ["top", "bottom"],
    "statusline": ["bottom"], "ribbon": ["bottom"], "rail": ["left", "right"], "corners": ["top", "bottom"],
    "dock": ["bottom", "left"],
}


ENVS = []


def scene(bar, **kw):
    env = PanelsEnv("panels-test", bar=bar, **kw)
    ENVS.append(env)
    win = env.scene(1600, 900, windows=False)
    QTest.qWait(150)
    host = env.h.find(win, "host")
    return env, win, host


def ev(env, obj, expr):
    return env.h.eval(obj, expr)


# Legacy config: one classic bar on top that reserves its depth
env, win, host = scene({"position": "top", "frameEnabled": False})
assert ev(env, host, "bars.length") == 1
assert ev(env, host, "primary.panelStyle") == "classic"
assert ev(env, host, "primary.spec.legacy") is True
top = ev(env, host, "zones.top")
assert top == ev(env, host, "primary.barTargetHeight + primary.baseOuterMargin") and top > 0, top
assert ev(env, host, "zones.bottom") == 0
assert ev(env, host, "hitRegions.length") == 1
assert ev(env, host, "EdgeService.insets(screen, {dock: false, notch: false}).top") == top
# Content/style changes must update the measured placement depth too.
ev(env, host, "Config.bar.panels = [{id: 'rail', edge: 'right', thickness: 80, margin: 12}]")
QTest.qWait(150)
assert ev(env, host, "EdgeService.insets(screen, {dock: false, notch: false}).right") == 92
assert ev(env, host, "EdgeService.insets(screen, {dock: false, notch: false}).top") == 0
win.close()

# Mac: menubar + floating dock; both edges reserved, dock sized to content
env, win, host = scene({"frameEnabled": False, "panels": [
    {"id": "menubar", "edge": "top", "style": "menubar", "groups": {"start": ["launcher", "windowTitle", "appMenu"], "end": ["clock"]}},
    {"id": "dock", "edge": "bottom", "style": "dock", "autohide": "never", "groups": {"center": ["taskbar"], "end": ["downloads"]}},
]})
assert ev(env, host, "bars.length") == 2
assert ev(env, host, "primary.panelId") == "menubar", "the notch (top) pairs with the menubar"
menubar_h = ev(env, host, "bars[0].barTargetHeight")
assert 24 <= menubar_h <= 34, menubar_h
assert ev(env, host, "zones.top") == menubar_h
dock = "bars[1]"
assert ev(env, host, dock + ".panelThickness") >= 52
assert ev(env, host, dock + ".spanLength") < 1600, "a dock does not fill the edge"
assert ev(env, host, dock + ".barHitbox.width") == ev(env, host, dock + ".spanLength")
assert ev(env, host, "zones.bottom") == ev(env, host, dock + ".edgeDepth")
assert ev(env, host, "hitRegions.length") == 2
assert ev(env, host, "EdgeService.insets(screen, {dock: false, notch: false}).top") == menubar_h
assert ev(env, host, "EdgeService.insets(screen, {dock: false, notch: false}).bottom") == ev(env, host, dock + ".edgeDepth")
win.close()

# Zen: the panel hides itself and reserves nothing
env, win, host = scene({"panels": [{"id": "zen", "edge": "top", "style": "islands", "autohide": "always", "reserve": False,
                                    "groups": {"start": ["clock"]}}]})
assert ev(env, host, "primary.reveal") is False
assert ev(env, host, "zones.top") == 0
win.close()

# Screen filter
env, win, host = scene({"panels": [{"id": "tv", "screens": ["HDMI-A-1"]}, {"id": "here", "screens": ["primary"]}]})
assert ev(env, host, "bars.length") == 1 and ev(env, host, "bars[0].panelId") == "here"
win.close()

# Every style loads on each edge it supports and sizes itself
for style, edges in STYLES.items():
    for edge in edges:
        env, win, host = scene({"frameEnabled": True, "panels": [{"id": "p", "edge": edge, "style": style,
                                "groups": {"start": ["launcher", "workspaces"], "center": ["clock"], "end": ["systemStats", "battery"],
                                           "gapStart": ["weather"]}}]})
        assert ev(env, host, "primary.styleItem !== null"), (style, edge)
        assert ev(env, host, "primary.panelThickness") > 0, (style, edge)
        win.close()

# One keybind press flips the shared pin once, whatever the number of panels
env, win, host = scene({"pinnedOnStartup": True, "panels": [{"id": "a", "edge": "top"}, {"id": "b", "edge": "bottom"}]})
ev(env, host, "GlobalStates.barPinToggled()")
QTest.qWait(50)
assert ev(env, host, "Config.bar.pinnedOnStartup") is False
assert ev(env, host, "bars[0].pinned") is False and ev(env, host, "bars[1].pinned") is False
assert ev(env, host, "zones.top") == 0
win.close()
errors = [e for env in ENVS for e in env.h.type_errors]
assert not errors, errors
print("panels: ok", flush=True)
# PySide tears several QML engines down in an order that can crash; every
# check passed, leave without running the destructors.
os._exit(0)
