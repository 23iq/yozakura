"""LoadWatch (modules/components/preview): an asynchronous Loader build that
stays Loading is retried a few times, never while unwanted, and the count
starts over once the build lands. LivePart and the home tiles' scenes use it."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, wait_until  # noqa: E402

h = Harness("load-watch")
h.copy("modules/components/preview/LoadWatch.qml", siblings=False)
root = h.load("""
import QtQuick
Item {
    property int retries: 0
    property alias wanted: watch.wanted
    property alias tries: watch.tries
    QtObject { id: fake; objectName: "fake"; property int status: Loader.Loading }
    function setStatus(s) { fake.status = s; }
    function arm() { watch.arm(); }
    function running() { return watch.running; }
    LoadWatch {
        id: watch
        interval: 30
        loader: fake
        onRetry: { parent.retries++; watch.arm(); }
    }
}
""", auto_stub=False)

ev = lambda e: h.eval(root, e)  # noqa: E731

# stuck: retried maxTries (3) times, then left alone
ev("arm()")
wait_until(lambda: ev("retries") == 3)
pump(200)
assert ev("retries") == 3, ev("retries")

# landed: the count starts over on the next check
ev("setStatus(Loader.Ready)")
ev("arm()")
wait_until(lambda: ev("tries") == 0)
assert not ev("running()")

# stuck again: retried again
ev("setStatus(Loader.Loading)")
ev("arm()")
wait_until(lambda: ev("retries") == 4)

# not wanted: never retried
ev("retries = 0")
ev("tries = 0")
ev("wanted = false")
ev("arm()")
pump(200)
assert ev("retries") == 0, ev("retries")
print("PASS load-watch")
h.exit(0)
