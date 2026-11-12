#!/usr/bin/env python3
"""ProcessRole gating: a separate window process claims nothing session-wide.

The real services over stubs, once as the main shell (no <PREFIX>ROLE) and
once as a separate Settings window (ROLE=settings, performance.
separateWindows, modules/globals/ProcessRole.qml). A fake BackendService
records every subscription and call, a fake Process every command started.
As the main shell each service does what it always did; as the Settings
window none of them registers the notification server, reads or writes the
notification history, takes the `notify` / `ui` / `sleep` / `timers` /
`wallpaper` / `preset` streams, starts the IPC FIFO reader or a scheduled
update check, or runs a command it received; a notification it raises is
handed to the daemon (notify.send) for the main shell to show.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from qmlharness import Harness, hard_exit, process_role_qml  # noqa: E402

from waits import pump, settle  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


LOG = """pragma Singleton
QtObject {
    property var subs: []
    property var calls: []
    property var started: []
    property int servers: 0
    property var writes: []
}"""
BACKEND = """pragma Singleton
import testlog
QtObject {
    property bool socketAvailable: true
    function addSubscription(s, cb) { Log.subs = Log.subs.concat(s); return Log.subs.length }
    function removeSubscription(h) {}
    function setSubscriptionActive(h, a) {}
    function call(m, p, cb) { Log.calls = Log.calls.concat([{ "method": m, "params": p || null }]) }
    function notify(m, p) { call(m, p) }
    function callOk(m, p, ok) { call(m, p) }
}"""
PROCESS = """import testlog
QtObject {
    id: p
    property var command: []
    property bool running: false
    property var stdout
    property var stderr
    signal exited(int code)
    onRunningChanged: if (running) Log.started = Log.started.concat([JSON.stringify(command)])
    Component.onCompleted: if (running) Log.started = Log.started.concat([JSON.stringify(command)])
}"""
FILEVIEW = """import testlog
QtObject {
    id: v
    property string path
    property bool watchChanges
    property bool printErrors
    property bool blockWrites
    property bool atomicWrites
    property var adapter
    signal loaded()
    signal loadFailed(int error)
    signal fileChanged()
    function text() { return "" }
    function reload() {}
    function setText(t) { Log.writes = Log.writes.concat([v.path]) }
    function writeAdapter() { Log.writes = Log.writes.concat([v.path]) }
}"""
SERVER = """import testlog
QtObject {
    property bool actionsSupported; property bool bodyHyperlinksSupported
    property bool bodyImagesSupported; property bool bodyMarkupSupported
    property bool bodySupported; property bool imageSupported; property bool keepOnReload
    property bool persistenceSupported; property var extraHints
    property var trackedNotifications: ({ values: [] })
    signal notification(var notification)
    Component.onCompleted: Log.servers++
}"""


def scene(role: str):
    tag = role or "shell"
    h = Harness(f"process-role-{tag}")
    h.module("testlog", {"Log": LOG})
    h.module("Quickshell", {
        "Singleton": "QtObject { default property list<QtObject> data }",
        "Quickshell": "pragma Singleton\nQtObject { property var screens: []; function env(n) { return \"\" } "
                      "function execDetached(a) {} }",
    })
    h.module("Quickshell.Io", {"Process": PROCESS, "FileView": FILEVIEW,
                               "SplitParser": "QtObject { signal read(string data) }",
                               "StdioCollector": "QtObject { property string text; signal streamFinished() }",
                               "IpcHandler": "QtObject { property string target }"})
    h.module("Quickshell.Services.Notifications", {
        "NotificationServer": SERVER,
        "NotificationUrgency": "QtObject { enum Urgency { Low, Normal, Critical } }",
        "Notification": "QtObject {}",
    })
    h.module("qs.modules.globals", {
        "ProcessRole": process_role_qml(role),
        "GlobalStates": "pragma Singleton\nQtObject { property bool settingsWindowVisible: false; "
                        "property string settingsCategory: \"\"; property var wallpaperManager: null; "
                        "function focusedScreenName() { return \"\" } }",
    })
    h.module("qs.modules.services", {
        "BackendService": BACKEND,
        "SuspendManager": "pragma Singleton\nQtObject { property bool isSuspending: false; signal wakingUp() }",
        "I18n": "pragma Singleton\nQtObject { function t(k) { return k } function has(k) { return false } }",
        "YozdService": "pragma Singleton\nQtObject { property var clients: ({ values: [] }); function dispatch(c) {} }",
        "StateService": "pragma Singleton\nQtObject { property bool initialized: true; "
                        "function get(k, d) { return d } function set(k, v) {} }",
        "PresetsService": "pragma Singleton\nQtObject { function loadPreset(n) {} }",
    })
    h.module("qs.modules.desktop.widgets", {"Unused": "QtObject {}"})
    h.module("qs.modules.specials", {"Unused": "QtObject {}"})
    h.singleton("qs.config", "Config", """QtObject {
        property var notifications: ({ maxVisible: 10, historySize: 100, groupByApp: true })
        property var system: ({ updateServiceEnabled: true, idle: { listeners: [], general: {} } })
        property var prefix: ({ clipboard: "cc", emoji: "ee", tmux: "tt", notes: "nn" })
        property bool initialLoadComplete: true
        property string version: "1.0"
    }""")

    services = "qs/modules/services"
    h.copy("modules/services/Notifications.qml", services, strip_singleton=True, siblings=False)
    for helper in ("NotificationHistoryFile", "NotificationHideQueue", "NotificationReaper"):
        h.copy(f"modules/services/{helper}.qml", services, siblings=False)
    h.stub("NotificationRules", """QtObject {
        property bool silent: false
        property string presentation: "notch"
        property string cornerPosition: "top-right"
        function decide(info) { return { "popup": true, "timeout": 5000, "priority": false, "sound": false } }
        function playSound(h) {}
    }""", services)
    h.copy("modules/services/GlobalShortcuts.qml", services, strip_singleton=True, siblings=False)
    h.copy("modules/services/TimersService.qml", services, strip_singleton=True, siblings=False)
    h.copy("modules/services/WallpaperCommandService.qml", services, strip_singleton=True, siblings=False)
    h.copy("modules/services/PresetCommandService.qml", services, strip_singleton=True, siblings=False)
    # The check itself (a GitHub request) is recorded instead of made.
    h.copy("modules/services/UpdateService.qml", services, strip_singleton=True, siblings=False,
           replace={"interval: 2000": "interval: 50",
                    "import qs.modules.globals\n": "import qs.modules.globals\nimport testlog\n",
                    "        root.checking = true;\n": "        Log.started = Log.started.concat([\"update-check\"]);\n"
                                                   "        return;\n"})
    h.module("qs.modules.services.timers", {
        "AlarmPlayer": "QtObject { property bool ringing; property string tone; function play(t) {} function start() {} function stop() {} }"})
    h.module("qs.modules.services", {})  # list the copied files in the qmldir
    root = h.load("""
import QtQuick
import testlog
import qs.modules.services
import qs.modules.globals
Item {
    property alias notifications: n
    property alias shortcuts: g
    Notifications { id: n }
    GlobalShortcuts { id: g }
    TimersService {}
    WallpaperCommandService {}
    PresetCommandService {}
    UpdateService {}
    function log() {
        return JSON.stringify({ subs: Log.subs, calls: Log.calls, started: Log.started,
                                servers: Log.servers, writes: Log.writes });
    }
}""")
    settle()
    pump(400)  # the deferred history reload, the update check (50 ms here)
    return h, root


def log(h, root):
    return json.loads(h.eval(root, "log()"))


# The main shell: everything as before.
h, root = scene("")
first = log(h, root)
check(first["servers"] == 1, f"main shell: the notification server is registered, got {first['servers']}")
for svc in ("notify", "ui", "timers", "wallpaper", "preset"):
    check(svc in first["subs"], f"main shell: subscribes to {svc!r}, got {first['subs']}")
check(any("ipc.pipe" in c for c in first["started"]), f"main shell: the IPC FIFO reader runs, got {first['started']}")
check(h.eval(root, "notifications.notifServer !== null") is True, "main shell: notifServer is the server")
check("update-check" in first["started"], f"main shell: the scheduled update check runs, got {first['started']}")
n = h.eval(root, "notifications.notifyInternal({ summary: 'hello', body: 'b' }) !== null")
check(n is True, "main shell: notifyInternal makes a tracked notification")

# A separate Settings window: nothing session-wide.
h2, root2 = scene("settings")
sec = log(h2, root2)
check(sec["servers"] == 0, f"settings window: no notification server, got {sec['servers']}")
for svc in ("notify", "ui", "timers", "wallpaper", "preset"):
    check(svc not in sec["subs"], f"settings window: no {svc!r} stream, got {sec['subs']}")
check(not any("ipc.pipe" in c for c in sec["started"]), f"settings window: no FIFO reader, got {sec['started']}")
check(h2.eval(root2, "notifications.notifServer") is None, "settings window: notifServer is null")
check(h2.eval(root2, "notifications.serverNotifications") is None, "settings window: no server notifications")
before = len(sec["calls"])
ret = h2.eval(root2, "notifications.notifyInternal({ summary: 'Copied', body: '#fff', urgency: 2, appName: 'Yozakura' })")
check(ret is None, "settings window: notifyInternal makes no local notification")
after = log(h2, root2)
sent = [c for c in after["calls"][before:] if c["method"] == "notify.send"]
check(len(sent) == 1 and sent[0]["params"]["summary"] == "Copied" and sent[0]["params"]["urgency"] == "critical",
      f"settings window: the notification goes to the daemon (notify.send), got {after['calls'][before:]}")
check(h2.eval(root2, "notifications.list.length") == 0, "settings window: nothing in the history")
h2.eval(root2, "notifications.discardAllNotifications()")
pump(700)  # a history save would be written after its debounce
check(not any("notifications.json" in w for w in log(h2, root2)["writes"]),
      "settings window: the notification history is never written")
check(not any(c["method"] == "system.heartbeat" for c in after["calls"]), "settings window: no heartbeat")
check("update-check" not in after["started"], f"settings window: no scheduled update check, got {after['started']}")
# a command it hears is never run here (only reported, for the wizard's tour)
h2.eval(root2, "shortcuts.run('config')")
check(h2.eval(root2, "GlobalStates.settingsWindowVisible") is False, "settings window: a heard command is not run")

if failures:
    print(f"{len(failures)} failure(s)")
    hard_exit(1)
print("process-role: ok")
hard_exit(0)
