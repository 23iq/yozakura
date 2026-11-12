"""ExtrasService (real) offscreen: the install queue lives in the daemon, so a
lost backend connection drops running and queued jobs (a stale password wait
must not keep the setup wizard stepped aside); finished ones stay, and the
subscription's snapshot after the reconnect brings back live ones.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + str(detail) if detail else ""))


h = Harness("extras-reconnect")
h.module("Quickshell", {"Singleton": "Item {}"})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command: []; property bool running: false; signal exited(int code, int status) }",
})
svc = "qs/modules/services"
h.module("qs.modules.services", {
    "BackendService": """pragma Singleton
QtObject {
    property bool socketAvailable: true
    property var cb: null
    function call(m, p, c) {}
    function addSubscription(s, c) { cb = c; return 1 }
}""",
})
h.copy("modules/services/ExtrasService.qml", dest=svc, siblings=False)
h._write_qmldir(h.root / svc, "qs.modules.services")

root = h.load("""
import QtQuick
import qs.modules.services
Item {
    function sub() { ExtrasService.load() }
    function event(p) { BackendService.cb("extras.progress", p) }
    function setUp(v) { BackendService.socketAvailable = v }
    function auth() { return ExtrasService.awaitingAuth }
    function busy() { return ExtrasService.busy }
    function jobIds() { return Object.keys(ExtrasService.jobs).sort().join(",") }
    function progressIds() { return Object.keys(ExtrasService.progress).sort().join(",") }
}
""", auto_stub=False)


def settle():
    for _ in range(3):
        h.app.processEvents()


h.eval(root, "sub()")
h.eval(root, "event({job: 'j1', kind: 'chsh', entries: [], state: 'running', auth: true})")
h.eval(root, "event({job: 'j2', kind: 'install', entries: ['firefox'], state: 'queued'})")
h.eval(root, "event({job: 'j0', kind: 'install', entries: ['steam'], state: 'done'})")
settle()
check("a running job waits for the password", h.eval(root, "auth()") is True and h.eval(root, "busy()") is True)
h.eval(root, "setUp(false)")
settle()
check("connection lost: no password wait left", h.eval(root, "auth()") is False and h.eval(root, "busy()") is False)
check("finished jobs and their progress stay", h.eval(root, "jobIds()") == "j0" and h.eval(root, "progressIds()") == "steam",
      (h.eval(root, "jobIds()"), h.eval(root, "progressIds()")))
h.eval(root, "setUp(true)")
h.eval(root, "event({job: 'j2', kind: 'install', entries: ['firefox'], state: 'running'})")
settle()
check("the snapshot after the reconnect brings live jobs back", h.eval(root, "jobIds()") == "j0,j2" and h.eval(root, "busy()") is True)

print("extras reconnect " + ("passed" if ok_all else "FAILED"))
sys.exit(0 if ok_all else 1)
