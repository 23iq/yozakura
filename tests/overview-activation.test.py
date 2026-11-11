"""OverviewActivation (modules/widgets/overview): "close the overview and
activate this window", the one path behind a click on a preview and Enter on
a search match.

The overview holds exclusive keyboard focus; Hyprland refuses keyboard focus
to a window while it does. So the request goes out at once (the workspace
switch starts with the click) and once more when the last overview surface
has unmapped, never in between. A second click before that retargets, a
window closed meanwhile is not asked for again, and reopening the overview
drops the pending request.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import settle  # noqa: E402

FAILED = []


def check(cond, msg):
    if not cond:
        print("FAIL:", msg)
        FAILED.append(msg)


h = Harness("overview-activation")
h.module("Quickshell", {"Singleton": "QtObject { default property list<QtObject> data }"})
h.singleton("qs.modules.services", "Visibilities", """QtObject {
    property string currentActiveModule: "overview"
    property bool hasMonitor: true
    // [module, number of arguments] per call
    property var calls: []
    function setActiveModule(moduleName) {
        calls = calls.concat([[moduleName, arguments.length]]);
        if (hasMonitor)
            currentActiveModule = moduleName;
    }
}""")
h.singleton("qs.modules.services", "YozdService", """QtObject {
    property var log: []
    function dispatch(command) { log = log.concat([command]) }
    function switchWorkspaceKeepCursor(w) { log = log.concat(["workspace " + w + " keep-cursor"]) }
}""")
h.singleton("qs.modules.bar.workspaces", "CompositorData", """QtObject {
    property var windowByAddress: ({ "0xa": { address: "0xa" }, "0xb": { address: "0xb" } })
}""")
h.copy("modules/widgets/overview/OverviewActivation.qml", "qs/modules/widgets/overview", siblings=False)
h.module("qs.modules.widgets.overview", {})

root = h.load("""import QtQuick
import qs.modules.services
import qs.modules.bar.workspaces
import qs.modules.widgets.overview
Item {
    property var act: OverviewActivation
    property var vis: Visibilities
    property var yozd: YozdService
    property var comp: CompositorData
    // Two screens, two overview surfaces
    Item { objectName: "surfaceA" }
    Item { objectName: "surfaceB" }
}""", auto_stub=False)
a, b = h.find(root, "surfaceA"), h.find(root, "surfaceB")
FOCUS_A, FOCUS_B = "focuswindow address:0xa", "focuswindow address:0xb"


def ev(expr):
    return h.eval(root, expr)


def log():
    return json.loads(ev("JSON.stringify(yozd.log)"))


def closes():
    return json.loads(ev("JSON.stringify(vis.calls)"))


def reset(mapped=("surfaceA",)):
    """A fresh open overview: mapped on the given surfaces, nothing pending."""
    ev("yozd.log = []; vis.calls = []; vis.hasMonitor = true; vis.currentActiveModule = 'overview'")
    for name, surface in (("surfaceA", a), ("surfaceB", b)):
        h.eval(surface, f"OverviewActivation.setMapped(this, {'true' if name in mapped else 'false'})")
    ev("act.pending = ''; yozd.log = []")


def unmap(surface, turn=True):
    """The surface reports its unmap; `turn` lets the event loop come round."""
    h.eval(surface, "OverviewActivation.setMapped(this, false)")
    if turn:
        settle()


# One click: the overview closes, the request goes out at once and once more
# when the surface is gone.
reset()
ev("act.activate('0xa')")
check(closes() == [["", 1]], f"closes the overview once, with one argument: {closes()}")
check(log() == [FOCUS_A], f"the workspace switch starts with the click: {log()}")
check(ev("act.pending") == "0xa", "the window waits for the unmap")
settle()
check(log() == [FOCUS_A], f"nothing more while the overview is mapped: {log()}")
unmap(a, turn=False)
check(log() == [FOCUS_A], f"not from inside the unmap report (the window is still being hidden): {log()}")
settle()
check(log() == [FOCUS_A, FOCUS_A], f"asked again once the overview has unmapped: {log()}")
check(ev("act.pending") == "", "nothing left pending")
unmap(a)
check(len(log()) == 2, "a repeated unmap report asks nothing more")

# Several screens: only the last surface to unmap releases the request.
reset(mapped=("surfaceA", "surfaceB"))
ev("act.activate('0xa')")
unmap(a)
check(log() == [FOCUS_A], f"another overview surface is still mapped: {log()}")
unmap(b)
check(log() == [FOCUS_A, FOCUS_A], f"asked again after the last surface unmapped: {log()}")

# Mapped again before the event loop came round: still not the time.
reset()
ev("act.activate('0xa')")
unmap(a, turn=False)
h.eval(a, "OverviewActivation.setMapped(this, true)")
settle()
check(log() == [FOCUS_A] and ev("act.pending") == "0xa", f"a surface mapped again keeps the request waiting: {log()}")
unmap(a)
check(log() == [FOCUS_A, FOCUS_A], f"and it leaves after the real unmap: {log()}")

# A second click before the overview is gone: the last window wins.
reset()
ev("act.activate('0xa')")
ev("act.activate('0xb')")
check(log() == [FOCUS_A, FOCUS_B], f"each click is sent at once: {log()}")
unmap(a)
check(log() == [FOCUS_A, FOCUS_B, FOCUS_B], f"only the last clicked window is confirmed: {log()}")

# The window closed while the overview was closing: nothing to ask for.
reset()
ev("act.activate('0xa')")
ev("comp.windowByAddress = { '0xb': { address: '0xb' } }")
unmap(a)
check(log() == [FOCUS_A], f"a closed window is not focused again: {log()}")
check(ev("act.pending") == "", "the closed window is forgotten")
ev("comp.windowByAddress = { '0xa': { address: '0xa' }, '0xb': { address: '0xb' } }")

# The overview reopened before it unmapped: the old request is dropped.
reset()
ev("act.activate('0xa')")
ev("vis.currentActiveModule = 'overview'")
check(ev("act.pending") == "", "reopening drops the pending window")
ev("vis.currentActiveModule = ''")
unmap(a)
check(log() == [FOCUS_A], f"a later close focuses nothing stale: {log()}")

# No overview surface on screen: the one request is already after the unmap.
reset(mapped=())
ev("act.activate('0xa')")
check(log() == [FOCUS_A] and ev("act.pending") == "", f"one request when nothing is mapped: {log()}")

# The close was refused (no focused monitor): the overview stays, nothing waits.
reset()
ev("vis.hasMonitor = false")
ev("act.activate('0xa')")
check(ev("act.pending") == "", "nothing pends on an overview that stays open")

# No window, no request.
reset()
ev("act.activate(''); act.activate(undefined); act.activate(null)")
check(log() == [] and closes() == [], "an empty address closes and focuses nothing")

if FAILED:
    print(f"overview-activation: {len(FAILED)} failed")
    h.exit(1)
print("overview-activation: ok")
h.exit(0)
