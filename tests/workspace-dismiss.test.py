"""An open shell module closes when the workspace on its screen changes.

Hyprland jumps back to the old workspace when a module holding exclusive
keyboard focus closes after super+2 (the last focused window is restored), so
Visibilities dismisses the module on the switch itself. The real Visibilities
runs against a stub YozdService fed like the compositor state."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("workspace-dismiss")
h.module("Quickshell", {"Singleton": "Item {}"})
h.singleton("qs.modules.services", "YozdService", """QtObject {
    id: yroot
    property var focusedMonitor: null
    property QtObject monitors: QtObject { property var values: [] }
    function monitorFor(screen) {
        const n = screen ? (screen.name || screen) : "";
        const v = yroot.monitors.values || [];
        for (let i = 0; i < v.length; i++)
            if (v[i].name === n) return v[i];
        return null;
    }
    // Monitors "A" and "B" with the given active workspaces; `focus` is focused.
    function state(a, b, focus) {
        const mons = [
            {name: "A", focused: focus === "A", activeWorkspace: {id: a, name: String(a)}},
            {name: "B", focused: focus === "B", activeWorkspace: {id: b, name: String(b)}}
        ];
        yroot.monitors.values = mons;
        const f = mons.find(m => m.focused);
        if (!yroot.focusedMonitor || yroot.focusedMonitor.name !== f.name)
            yroot.focusedMonitor = f;
    }
}""")
h.copy("modules/services/Visibilities.qml", "qs/modules/services")
h.copy("modules/services/PolkitService.qml", "qs/modules/services")
h.module("qs.modules.services", {})
root = h.load("""import QtQuick
import qs.modules.services
Item {
    objectName: "root"
}""", auto_stub=False)


def ev(expr):
    return h.eval(root, expr)


def settle():
    for _ in range(3):
        h.app.processEvents()


def shown(module, screen="A"):
    return ev(f'Visibilities.getForScreen("{screen}").{module}')


ev('YozdService.state(1, 5, "A")')
settle()

# super+2 under the open launcher closes it
ev('Visibilities.setActiveModule("launcher")')
settle()
assert shown("launcher"), "launcher did not open"
ev('YozdService.state(2, 5, "A")')
settle()
assert not shown("launcher") and ev("Visibilities.currentActiveModule") == "", "launcher stayed open over the switch"

# Unrelated compositor state (same workspaces, other monitor's workspace) keeps it open
ev('Visibilities.setActiveModule("dashboard")')
settle()
ev('YozdService.state(2, 5, "A")')
ev('YozdService.state(2, 6, "A")')
settle()
assert shown("dashboard"), "dashboard closed without a switch on its screen"

# Focus moves to the other monitor: the module follows it, nothing closes
ev('YozdService.state(2, 6, "B")')
settle()
assert shown("dashboard", "B") and not shown("dashboard", "A"), "dashboard did not follow the focused monitor"
ev('YozdService.state(2, 7, "B")')
settle()
assert not shown("dashboard", "B"), "switch on the new screen did not close the dashboard"

# The overview switches workspaces itself: it stays open
ev('YozdService.state(2, 7, "A")')
settle()
ev('Visibilities.setActiveModule("overview")')
settle()
ev('YozdService.state(3, 7, "A")')
settle()
assert shown("overview"), "overview closed on its own workspace step"
ev('Visibilities.setActiveModule("")')
settle()

# Nothing open: a switch changes nothing
ev('YozdService.state(4, 7, "A")')
settle()
assert ev("Visibilities.currentActiveModule") == ""
print("workspace-dismiss: ok")
h.exit(0)
