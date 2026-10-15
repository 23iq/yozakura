"""A failed/cancelled freeze must let the next screenshot start immediately."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness, brand_qml  # noqa: E402
from PySide6.QtCore import QEventLoop, QTimer  # noqa: E402

h = Harness("screenshot-service")
h.module("Quickshell", {
    "Quickshell": "pragma Singleton\nQtObject { property var screens: [{ name: 'DP-1', x: 0, y: 0, width: 1920, height: 1080, scale: 1 }] }",
})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command; property bool running; property QtObject stdout; property QtObject stderr; signal exited(int exitCode) }",
    "StdioCollector": "QtObject { property string text: '' }",
})
h.singleton("qs.modules.globals", "Brand", brand_qml())
h.singleton("qs.config", "Config", "QtObject {}")
h.singleton("qs.modules.services", "BackendService", """QtObject {
    property var calls: []
    function call(method, params, callback) { calls.push({ method: method, params: params, callback: callback }); }
    function reply(index, result, error) { calls.filter(c => c.method === 'screenshot.frame')[index].callback(result, error); }
    function replyCapture(index, result, error) { calls.filter(c => c.method === 'screenshot.capture')[index].callback(result, error); }
}""")
source = h.copy("modules/services/Screenshot.qml", strip_singleton=True, siblings=False)
source.write_text("import qs.modules.services\n" + source.read_text())
root = h.load("""import qs.modules.services
import Quickshell
Item {
    property var backend: BackendService
    property var screens: Quickshell
    property int errors: 0
    property int ready: 0
    property var saved: []
    property string lastError: ''
    property var svc: shot
    Screenshot {
        id: shot
        onErrorOccurred: message => { errors++; lastError = message; }
        onMonitorScreenshotReady: (monitor, path) => ready++
        onImageSaved: path => saved.push(path)
    }
}""", auto_stub=False)


def ev(code):
    return h.eval(root, code)


ev("svc.freezeScreen(); backend.reply(0, null, 'frame timeout')")
assert ev("errors") == 1, "frame errors must leave loading through errorOccurred"
assert ev("lastError.indexOf('DP-1') >= 0 && lastError.indexOf('frame timeout') >= 0"), "diagnostic must name output and backend cause"
ev("svc.freezeScreen(); svc.releaseFrozenFrames(); svc.freezeScreen()")
assert ev("backend.calls.filter(c => c.method === 'screenshot.frame').length") == 3, "cancelled capture must not block retry"
ev("backend.reply(1, { path: '/tmp/obsolete.png' }, null)")
assert ev("ready") == 0, "late reply must not activate the cancelled/reopened overlay"
ev("backend.reply(2, { path: '/tmp/current.png' }, null)")
assert ev("ready") == 1, "new attempt must receive its own frame"
assert ev("svc._freezing") is False, "new attempt must finish despite the stale reply"
ev("svc._freezeTimeout.interval = 20; svc.freezeScreen()")
loop = QEventLoop()
QTimer.singleShot(60, loop.quit)
loop.exec()
assert ev("errors") == 2, "missing backend replies must release the overlay through errorOccurred"
assert ev("svc._freezing") is False, "watchdog must allow an immediate retry"
ev("svc.freezeScreen(); backend.reply(3, { path: '/tmp/expired.png' }, null)")
assert ev("ready") == 1, "watchdog must invalidate the expired frame reply"
ev("backend.reply(4, { path: '/tmp/retry.png' }, null)")
assert ev("ready") == 2, "retry after watchdog must receive its own frame"
ev("screens.screens = []; svc.freezeScreen()")
assert ev("errors") == 3, "no screens must fail immediately"
assert ev("svc._freezing") is False, "no-screen attempt must not block future captures"

ev("screens.screens = [{ name: 'DP-1', x: 0, y: 0, width: 1920, height: 1080, scale: 1 }]; svc._freezeTimeout.interval = 10000")


def open_ready():
    index = ev("backend.calls.filter(c => c.method === 'screenshot.frame').length")
    ev("svc.freezeScreen()")
    ev(f"backend.reply({index}, {{ path: '/tmp/frame.png' }}, null)")


# Both capture modes close their own overlay before receiving the save result.
# An old save error must not dismiss a newly opened selection overlay.
for index, request in enumerate(["svc.processRegion(10, 20, 30, 40)", "svc.processMonitorScreen('DP-1')"]):
    open_ready()
    ev(request + "; svc.releaseFrozenFrames(); svc.freezeScreen()")
    ev(f"backend.replyCapture({index}, null, 'old capture timeout')")
    assert ev("errors") == 3, "obsolete capture errors must not close the new overlay"
    assert ev("svc._freezing") is True, "new freeze must continue after an old capture error"
    ev("svc.releaseFrozenFrames()")

open_ready()
ev("svc.captureMode = 'normal'; svc.processRegion(10, 20, 30, 40); svc.releaseFrozenFrames(); svc.captureMode = 'lens'; svc.freezeScreen()")
ev("backend.replyCapture(2, { path: '/tmp/saved-normal.png' }, null)")
assert ev("saved.length === 1 && saved[0] === '/tmp/saved-normal.png'"), "old normal success must still report the saved image"
assert ev("svc.lensProcess.running") is False, "new Lens mode must not reroute an old normal capture"
assert ev("svc.captureMode") == "lens", "old normal success must preserve the new capture mode"
ev("svc.releaseFrozenFrames()")

open_ready()
ev("svc.captureMode = 'lens'; svc.processMonitorScreen('DP-1'); svc.releaseFrozenFrames(); svc.freezeScreen()")
ev("backend.replyCapture(3, { path: '/tmp/saved-lens.png' }, null)")
assert ev("svc.lensProcess.command[2]") == "/tmp/saved-lens.png", "old Lens success must still open its own image"
assert ev("saved.length") == 1, "Lens success must not become a normal saved-image preview"
assert ev("svc.captureMode") == "lens", "old Lens success must not reset the new Lens attempt"
ev("svc.releaseFrozenFrames(); svc.captureMode = 'normal'; svc.processMonitorScreen('DP-1'); backend.replyCapture(4, null, 'current capture timeout')")
assert ev("errors") == 4, "current capture errors must retain their diagnostic signal"
print("PASS screenshot failure, cancellation and immediate retry")
h.exit(0)
