"""ActivityService + a real provider (TimerActivity over a TimersService stub)
offscreen: per-second labels, config gating and click routing through the
registry."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from lib import timers_stubs  # noqa: E402

h = Harness("activity-service")
h.singleton("qs.config", "Config", """QtObject {
    property var bar: ({ activities: { enabled: true, maxVisible: 4, sources: { timers: true } } })
}""")
h.module("Quickshell", {"Singleton": "Item {}"})
h.module("qs.modules.theme", {"Icons": "pragma Singleton\nQtObject { property string timer: \"T\"; property string alarm: \"A\"; property string downloadSimple: \"D\" }"})
h.module("qs.modules.services", {"I18n": "pragma Singleton\nQtObject { function t(k) { return k } }", **timers_stubs.services()})
timers_stubs.copy_js(h.root)

mod = "qs/modules/services/activities"
for name in ["ActivityService", "ActivityProvider", "TimerActivity"]:
    h.copy(f"modules/services/activities/{name}.qml", dest=mod, siblings=False)
(h.root / mod / "ActivityProviders.qml").write_text(
    "pragma Singleton\nimport QtQuick\nimport Quickshell\nimport qs.modules.services.activities\n"
    "Singleton { readonly property var all: [TimerActivity, FakeDownloads, FakeNotes] }\n")
for name, source in [("FakeDownloads", "browserDownloads"), ("FakeNotes", "notificationProgress")]:
    (h.root / mod / f"{name}.qml").write_text(
        "pragma Singleton\nimport QtQuick\nimport qs.modules.services.activities\n"
        f"ActivityProvider {{ source: \"{source}\"; configKey: \"\"; property var acted: []\n"
        "  function transferAction(t, a) { acted = acted.concat([t.id + '/' + a]); } }\n")
h._write_qmldir(h.root / mod, "qs.modules.services.activities")

root = h.load("""
import QtQuick
import qs.config
import qs.modules.services
import qs.modules.services.activities
Item {
    id: root
    readonly property var list: ActivityService.activities
    function run(left) { TimersService.timers = [{ id: "t1", name: "Focus", state: "running", ringing: false, leftMs: left, totalMs: 130000, progress: left / 130000, createdAt: 1 }]; }
    function pause() { TimersService.timers = [{ id: "t1", name: "Focus", state: "paused", ringing: false, leftMs: 64000, totalMs: 130000, createdAt: 1 }]; }
    function clear() { TimersService.timers = []; }
    function disable() { Config.bar = ({ activities: { enabled: true, sources: { timers: false } } }); }
    function enable() { Config.bar = ({ activities: { enabled: true, maxVisible: 4, sources: { timers: true } } }); }
    function click() { ActivityService.activate(ActivityService.activities[0], Qt.LeftButton, "DP-1"); }
}
""")

assert h.eval(root, "list.length") == 0
h.eval(root, "run(65000)")
QTest.qWait(10)
assert h.eval(root, "list.length") == 1
assert h.eval(root, "list[0].label") == "01:05"
assert abs(h.eval(root, "list[0].progress") - 0.5) < 1e-6
assert h.eval(root, "list[0].indicator") == "ring"
assert h.eval(root, "list[0].detail") == "Focus"
h.eval(root, "run(64000)")
QTest.qWait(10)
assert h.eval(root, "list[0].label") == "01:04", "per-second updates propagate"
h.eval(root, "click()")
assert h.eval(root, "TimersService.hubOpen") and h.eval(root, "TimersService.hubScreen") == "DP-1", "click opens the timers hub"
h.eval(root, "pause()")
QTest.qWait(10)
assert h.eval(root, "list.length") == 0, "paused timers are not live activities"
h.eval(root, "run(64000)")
QTest.qWait(10)
h.eval(root, "disable()")
QTest.qWait(10)
assert h.eval(root, "list.length") == 0, "bar.activities.sources.timers=false hides it"
h.eval(root, "clear()")
h.eval(root, "enable()")

# Transfers: de-duplicated across providers, one aggregated "downloads" activity
h.eval(root, """(function() {
    FakeDownloads.transfers = [
        { id: 'browserDownloads:a', source: 'browserDownloads', title: 'a.iso', path: '/d/a.iso.part', processed: 100, total: 400, rate: 10, state: 'running', actions: ['cancel'], startedAt: 1 },
        { id: 'browserDownloads:b', source: 'browserDownloads', title: 'b.iso', processed: 300, total: 400, rate: 10, state: 'running', startedAt: 2 }
    ];
    FakeNotes.transfers = [{ id: 'notificationProgress:x', source: 'notificationProgress', title: 'a.iso', processed: 25, total: 100, units: 'percent', startedAt: 3 }];
})()""")
QTest.qWait(10)
assert h.eval(root, "ActivityService.transfers.length") == 2, "notification merged into the .part download"
assert h.eval(root, "list.length") == 1
assert h.eval(root, "list[0].id") == "downloads"
assert h.eval(root, "list[0].label") == "2 · 50%"
assert h.eval(root, "ActivityService.tasks.length") == 1
h.eval(root, "ActivityService.transferAction(ActivityService.transfers[0], 'cancel')")
assert h.eval(root, "FakeDownloads.acted.join(',')") == "browserDownloads:a/cancel"
h.eval(root, "Config.bar = ({ activities: { enabled: true, downloads: { aggregate: false } } })")
QTest.qWait(10)
assert h.eval(root, "list.length") == 2, "aggregate off: one activity per transfer"
h.eval(root, "Config.bar = ({ activities: { enabled: true, presentation: 'off' } })")
QTest.qWait(10)
assert h.eval(root, "list.length") == 0 and h.eval(root, "ActivityService.presentation") == "off"
print("activity service: aggregation, updates, gating, click routing and downloads passed")
