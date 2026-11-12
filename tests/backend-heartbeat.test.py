#!/usr/bin/env python3
"""BackendService freeze-watchdog heartbeat, offscreen.

The real BackendService over a fake socket: once connected it sends
system.heartbeat with the Quickshell pid right away and then every few
seconds (the daemon's watchdog, backend/pkg/daemon/qsguard.go, kills a
shell that stops); a dry-run shell or a separate Settings window process
(ProcessRole), not the supervised one, sends none. A subscription names
the process in its subscribe request (clientId = the role: "shell" for the
main shell, the window kind for a window), which the daemon's preview relay
uses to wait only for a main shell (backend/pkg/svc/preview).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from qmlharness import REPO, Harness, dryrun_qml, hard_exit, process_role_qml  # noqa: E402

from waits import pump, wait_until  # noqa: E402

WIRE = """pragma Singleton
QtObject {
    property var sent: []
    function send(sock, line) {
        const msg = JSON.parse(line);
        sent = sent.concat([msg]);
        if (msg.method !== "subscribe")
            Qt.callLater(() => sock.parser.read(JSON.stringify({id: msg.id, result: msg.method === "ipc.hello" ? {protocol: 1} : {ok: true}})));
    }
}"""
SOCKET = """QtObject {
    id: s
    property string path
    property bool connected: false
    property var parser
    signal connectionStateChanged()
    signal error(var e)
    onConnectedChanged: connectionStateChanged()
    function write(line) { Wire.send(s, line.trim()) }
    function flush() {}
}"""
PARSER = "QtObject { signal read(string data) }"
QUICKSHELL = "pragma Singleton\nQtObject { readonly property int processId: 4242 }"

failures: list[str] = []
HEARTBEAT = "id: heartbeatTimer\n        interval: 3000\n"


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


def scene(name: str, dry: bool, role: str = ""):
    h = Harness(name)
    h.module("Quickshell", {"Singleton": "QtObject { default property list<QtObject> data }",
                            "Quickshell": QUICKSHELL})
    h.module("Quickshell.Io", {"Wire": WIRE, "Socket": SOCKET, "SplitParser": PARSER})
    h.module("qs.modules.globals", {"DryRun": dryrun_qml({"DRYRUN": "1"} if dry else {}),
                                    "ProcessRole": process_role_qml(role)})
    services = h.root / "qs/modules/services"
    services.mkdir(parents=True, exist_ok=True)
    for lib in ("DryRunBackend.js", "DryRunMethods.js"):
        (services / lib).write_text((REPO / "modules/services" / lib).read_text())
    backend = (REPO / "modules/services/BackendService.qml").read_text().replace("pragma Singleton\n", "")
    # The 3 s period pairs with the daemon's watchdog (qsguard.go); the
    # repeat is checked here at a tenth of it.
    assert HEARTBEAT in backend, "heartbeatTimer: 3000 ms"
    backend = backend.replace(HEARTBEAT, HEARTBEAT.replace("interval: 3000", "interval: 300"))
    h.module("qs.modules.services", {"BackendService": "pragma Singleton\n" + backend})
    root = h.load("""
import QtQuick
import Quickshell.Io
import qs.modules.services
Item {
    readonly property bool up: BackendService.socketAvailable
    function subscribe() { BackendService.addSubscription(["preview"], (service, data) => {}) }
    function subscribes() {
        return JSON.stringify(Wire.sent.filter(m => m.method === "subscribe").map(m => m.params));
    }
    function beats() {
        return JSON.stringify(Wire.sent.filter(m => m.method === "system.heartbeat").map(m => m.params));
    }
}""", auto_stub=False)
    return h, root


h, root = scene("backend-heartbeat", dry=False)
wait_until(lambda: h.eval(root, "up") is True and json.loads(h.eval(root, "beats()")) != [])
check(h.eval(root, "up") is True, "fake socket connected")
beats = json.loads(h.eval(root, "beats()"))
check(beats == [{"pid": 4242}], f"first heartbeat on connect with the pid, got {beats}")
wait_until(lambda: len(json.loads(h.eval(root, "beats()"))) >= 2)
beats = json.loads(h.eval(root, "beats()"))
check(len(beats) >= 2, f"heartbeat repeats (every 3 s; 300 ms here), got {len(beats)}")
h.eval(root, "subscribe()")
wait_until(lambda: json.loads(h.eval(root, "subscribes()")) != [])
subs = json.loads(h.eval(root, "subscribes()"))
check(subs == [{"clientId": "shell", "services": ["preview"]}], f"the main shell subscribes as \"shell\", got {subs}")

h2, root2 = scene("backend-heartbeat-dry", dry=True)
wait_until(lambda: h2.eval(root2, "up") is True)
pump(100)  # a heartbeat would go out at once (triggeredOnStart)
check(h2.eval(root2, "up") is True, "dry-run socket connected")
check(json.loads(h2.eval(root2, "beats()")) == [], "a dry-run shell sends no heartbeat")

h3, root3 = scene("backend-heartbeat-settings", dry=False, role="settings")
wait_until(lambda: h3.eval(root3, "up") is True)
pump(100)
check(h3.eval(root3, "up") is True, "settings-window socket connected")
check(json.loads(h3.eval(root3, "beats()")) == [], "a separate Settings window sends no heartbeat")
h3.eval(root3, "subscribe()")
wait_until(lambda: json.loads(h3.eval(root3, "subscribes()")) != [])
subs = json.loads(h3.eval(root3, "subscribes()"))
check(subs == [{"clientId": "settings", "services": ["preview"]}], f"a Settings window subscribes as \"settings\", got {subs}")

if failures:
    print(f"{len(failures)} failure(s)")
    hard_exit(1)
print("backend-heartbeat: ok")
hard_exit(0)
