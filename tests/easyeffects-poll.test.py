"""EasyEffectsService polls `easyeffects` only while a view shows its state
(setConsumer, like CavaService / SystemResources): no subprocess every 5 s
with nothing on screen, an immediate refresh when the first view appears."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("easyeffects-poll")
h.module("Quickshell", {"Singleton": "Item {}"})
h.singleton("Quickshell", "Quickshell", "QtObject { function execDetached(a) {} }")
h.singleton("qs.probe", "Probe", "QtObject { property var runs: [] }")
h.module("Quickshell.Io", {
    "Process": """import qs.probe
QtObject {
    property var command: []
    property bool running: false
    property var environment
    property var stdout
    property string buffer
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: {
        if (!running)
            return;
        Probe.runs = Probe.runs.concat([command.join(" ")]);
        running = false;
        exited(0, 0);
    }
}""",
    "SplitParser": "QtObject { signal read(string data) }",
})
h.module("qs.modules.globals", {})  # ProcessRole (the main shell)
h.copy("modules/services/EasyEffectsService.qml", "qs/modules/services")
h.module("qs.modules.services", {"SuspendManager": "pragma Singleton\nQtObject { property bool isSuspending: false }"})

root = h.load("""import QtQuick
import qs.modules.services
import qs.probe
Item {
    readonly property var svc: EasyEffectsService
}""", auto_stub=False)
svc = h.eval(root, "svc")


def runs():
    return h.eval(root, "Probe.runs.join('|')").split("|") if h.eval(root, "Probe.runs.length") else []


def polls():
    return [r for r in runs() if r in ("easyeffects -b 3", "easyeffects -a")]


h.eval(svc, "initialize()")
assert h.eval(svc, "available"), runs()
h.eval(root, "Probe.runs = []")
# Available but nothing shows it: no polling.
assert not h.eval(svc, "polling") and not h.eval(svc, "pollTimer.running")
# A view appears: refreshed at once, then polled.
h.eval(svc, 'setConsumer("panel", true)')
assert h.eval(svc, "polling") and h.eval(svc, "pollTimer.running")
assert len(polls()) >= 1, runs()
# Registering twice counts once; the last one leaving stops the polling.
h.eval(svc, 'setConsumer("panel", true); setConsumer("other", true)')
assert h.eval(svc, "consumerCount") == 2
h.eval(svc, 'setConsumer("panel", false)')
assert h.eval(svc, "pollTimer.running")
h.eval(svc, 'setConsumer("other", false)')
assert h.eval(svc, "consumerCount") == 0 and not h.eval(svc, "pollTimer.running")
print("easyeffects poll: ok")
h.exit(0)
