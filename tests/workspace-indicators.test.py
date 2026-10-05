"""Active workspace indicator styles (workspaces.indicatorStyle, registry
modules/bar/workspaces/indicators), offscreen in the real bar: every style
loads in horizontal and vertical bars, stays inside its box, the pill keeps
the classic geometry and the label color follows the style (on the fill or
accent on the bar)."""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

STYLES = ["pill", "underline", "dot", "brush", "bracket"]
FILLED = {"pill": True, "underline": False, "dot": False, "brush": True, "bracket": False}
failures: list[str] = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


FIND = """
function findItem(name, from) {
    var item = from;
    if (item.objectName === name) return item;
    var kids = item.children || [];
    for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
    return null;
}
"""

envs = []
for edge in ["top", "left"]:
    env = PanelsEnv(f"indicators-{edge}", bar={
        "position": edge, "frameEnabled": False, "panels": [],
        "layout": {"style": "classic", "left": ["workspaces"], "right": ["clock"], "drawer": []}},
        extra={"workspaces": {"showNumbers": True, "alwaysShowNumbers": True, "shown": 6}})
    envs.append(env)
    win = env.scene(1600, 900, windows=False)
    QTest.qWait(400)
    h = env.h

    def ev(expr, h=h, win=win):
        return h.eval(win, "(function(){" + FIND + "return (" + expr + ");})()")

    check(ev('findItem("activeIndicator", contentItem) !== null'), f"{edge}: workspaces have an active indicator")
    vertical = edge == "left"
    check(ev('findItem("activeIndicator", contentItem).vertical') == vertical, f"{edge}: orientation follows the bar")
    for style in STYLES:
        ev(f'Config.workspaces.indicatorStyle = "{style}"')
        QTest.qWait(250)
        ind = 'findItem("activeIndicator", contentItem)'
        item = 'findItem("indicatorStyle", ' + ind + ').item'
        check(ev(item + " !== null"), f"{edge}/{style}: style component loads")
        if ev(item + " === null"):
            continue
        check(ev(item + ".indicator === " + ind), f"{edge}/{style}: style gets its indicator")
        # the drawn shape stays inside the slot box (brush may overshoot 2 px along the bar)
        w, hgt, slot = ev(ind + ".width"), ev(ind + ".height"), ev(ind + ".slotSize")
        check(abs((hgt if vertical else w) - slot) < 0.5 and abs((w if vertical else hgt) - slot) < 0.5,
              f"{edge}/{style}: box is one slot at rest ({w}x{hgt}, slot {slot})")
        x, y = ev(item + ".x"), ev(item + ".y")
        iw, ih = ev(item + ".width"), ev(item + ".height")
        check(x >= -2.01 and y >= -2.01 and x + iw <= w + 2.01 and y + ih <= hgt + 2.01 and iw > 0 and ih > 0,
              f"{edge}/{style}: shape inside the box ({x},{y} {iw}x{ih} in {w}x{hgt})")
        expected = "Styling.srItem(\"primary\")" if FILLED[style] else "Colors.primary"
        check(ev("Qt.colorEqual(" + expected + ", (function(){ var b = findItem('wsButton', contentItem); return b ? b.activeColor : "
                 + expected + " })())"), f"{edge}/{style}: active label color")
        if style == "pill":
            # unchanged classic geometry: slot inset by 4 px
            check(ev(item + ".width") == w - 8 and ev(item + ".height") == hgt - 8, f"{edge}: pill keeps its 4 px inset")
    # unknown ids fall back to the pill
    ev('Config.workspaces.indicatorStyle = "zigzag"')
    QTest.qWait(200)
    check(ev('findItem("activeIndicator", contentItem).style.id') == "pill", f"{edge}: unknown style falls back to pill")
    errors = [e for e in h.type_errors if "indicators" in e or "ActiveIndicator" in e or "WorkspaceButton" in e]
    check(not errors, f"{edge}: no QML errors: {errors}")
    h.allow_type_errors = True
    win.close()

if failures:
    print(f"workspace-indicators: {len(failures)} failure(s)", flush=True)
    os._exit(1)
print("workspace-indicators: ok", flush=True)
# PySide tears several QML engines down in an order that can crash.
os._exit(0)
