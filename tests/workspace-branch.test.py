"""The "branch" workspace indicator (workspaces.indicatorStyle "branch",
modules/bar/workspaces/branch), offscreen in the real bar: the strip replaces
the active box, the occupied ranges and the slot contents in horizontal and
vertical bars, keeps a node per slot inside the widget, follows the window
counts and drops a petal when a window closes, but only with motion on."""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


FIND = """
function findItem(name, from) {
    if (from.objectName === name) return from;
    var kids = from.children || [];
    for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
    return null;
}
function nodes(strip) {
    var out = [];
    for (var i = 0; i < strip.children.length; i++)
        if (strip.children[i].previous !== undefined) out.push(strip.children[i]);
    return out;
}
"""

for edge in ["top", "left"]:
    vertical = edge == "left"
    env = PanelsEnv(f"branch-{edge}", bar={
        "position": edge, "frameEnabled": False, "panels": [],
        "layout": {"style": "classic", "left": ["workspaces"], "right": ["clock"], "drawer": []}},
        extra={"workspaces": {"shown": 6, "indicatorStyle": "branch"}})
    win = env.scene(1600, 900, windows=False)
    QTest.qWait(500)
    h = env.h

    def ev(expr, h=h, win=win):
        return h.eval(win, "(function(){" + FIND + "return (" + expr + ");})()")

    loader = h.eval(win, "(function(){" + FIND + "return findItem('workspaceStrip', contentItem);})()")
    check(loader is not None, f"{edge}: workspaces have a strip loader")
    if loader is None:
        continue

    def lv(expr, h=h, loader=loader):
        return h.eval(loader, "(function(){" + FIND + "return (" + expr + ");})()")

    check(lv("item !== null"), f"{edge}: branch strip loads")
    check(lv("item.vertical") == vertical, f"{edge}: strip orientation follows the bar")
    check(not ev('findItem("activeIndicator", contentItem).visible'), f"{edge}: active box hidden")
    check(not ev('findItem("wsButton", contentItem).background.visible'), f"{edge}: slot contents hidden")
    check(lv("nodes(item).length") == 6, f"{edge}: one node per slot ({lv('nodes(item).length')})")
    w, hh, slot = lv("item.width"), lv("item.height"), lv("item.slot")
    check(abs((hh if vertical else w) - 6 * slot) < 0.5 and abs((w if vertical else hh) - slot) < 0.5,
          f"{edge}: strip spans the slots ({w}x{hh}, slot {slot})")
    inside = lv("nodes(item).every(function(n) { var cx = n.x + n.width / 2, cy = n.y + n.height / 2;"
                " return cx > 0 && cy > 0 && cx < item.width && cy < item.height; })")
    check(inside, f"{edge}: node centres inside the strip")
    # fixture: workspace 2 active with two windows, 1/3 one, 4 three
    kinds = lv("nodes(item).map(function(n) { return n.state_.kind + n.state_.petals; }).join(',')")
    check(kinds == "blossom1,open5,blossom1,blossom3,bud0,bud0", f"{edge}: node states ({kinds})")

    # A window closes on workspace 4: its petal falls
    lv("(function(){ var m = Object.assign({}, CompositorData.workspaceWindowsMap); m['4'] = m['4'].slice(1);"
       " CompositorData.workspaceWindowsMap = m; return true; })()")
    QTest.qWait(60)
    check(lv("nodes(item)[3].state_.petals") == 2, f"{edge}: workspace 4 has two petals left")
    check(lv("nodes(item)[3].children[nodes(item)[3].children.length - 1].opacity") > 0, f"{edge}: a petal falls")
    # Urgent workspace 5: its bud trembles... and not at all with motion off
    lv("(function(){ CompositorData.workspaceUrgentMap = ({ 5: true }); return true; })()")
    QTest.qWait(60)
    check(lv("nodes(item)[4].state_.urgent"), f"{edge}: workspace 5 is urgent")
    lv("(function(){ Config.animDuration = 0; var m = Object.assign({}, CompositorData.workspaceWindowsMap);"
       " m['1'] = []; CompositorData.workspaceWindowsMap = m; return true; })()")
    QTest.qWait(60)
    check(lv("nodes(item)[0].state_.kind") == "bud", f"{edge}: workspace 1 back to a bud")
    check(lv("nodes(item)[0].children[nodes(item)[0].children.length - 1].opacity") == 0,
          f"{edge}: no falling petal with motion off")

    # Back to the pill: the strip unloads, the box returns
    ev('Config.workspaces.indicatorStyle = "pill"')
    QTest.qWait(200)
    check(not lv("active"), f"{edge}: strip unloads with a box style")
    check(ev('findItem("activeIndicator", contentItem).visible'), f"{edge}: active box back")
    errors = [e for e in h.type_errors if "branch" in e or "Workspaces.qml" in e or "WorkspaceButton" in e]
    check(not errors, f"{edge}: no QML errors: {errors}")
    h.allow_type_errors = True
    win.close()

if failures:
    print(f"workspace-branch: {len(failures)} failure(s)", flush=True)
    os._exit(1)
print("workspace-branch: ok", flush=True)
os._exit(0)
