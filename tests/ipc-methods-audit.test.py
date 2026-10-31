"""The ipc-methods audit extracts backend method names from QML and checks them against the registry."""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "audit"))
from checks import ipc_methods as m  # noqa: E402

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


REG = {
    "tasks": {"name": "tasks", "methods": ["list", "create"], "subscribe": True},
    "ui": {"name": "ui", "methods": ["run"], "subscribe": False},
}
WRAPPERS = [{"pattern": r"\broot\.call", "prefix": "tasks.", "files": ["modules/services/TasksService.qml"]},
            {"pattern": r"\bTasksService\.call", "prefix": "tasks."}]

SRC = '''
Item {
    // BackendService.call("nope.commented", {})
    Component.onCompleted: {
        BackendService.call("tasks.list", {}, r => {});
        BackendService.notify('ui.run', {});
        BackendService.call(
            "tasks.create", {});
        BackendService.call("tasks.missing", {});
        BackendService.call("ghost.thing", {});
        BackendService.call(method, {});
        BackendService.call("tasks." + name, {});
        TasksService.call("create", {});
        TasksService.call("bogus", {});
        root.call("list");
        BackendService.addSubscription(["tasks"], cb);
        BackendService.addSubscription(["ui", "nothing"], cb);
        BackendService.addSubscription(names, cb);
    }
}
'''

f = m.extract("modules/services/TasksService.qml", SRC, WRAPPERS)
got = {n for _, n in f["methods"]}
check(got == {"tasks.list", "ui.run", "tasks.create", "tasks.missing", "ghost.thing", "tasks.bogus"},
      f"literal and wrapper methods, comment ignored: {got}")
check("tasks.list" in got and len([1 for _, n in f["methods"] if n == "tasks.list"]) == 2,
      "root.call in the wrapper's own file counts, once per call site")
check([p for _, p in f["dynamic"]] == ["", "tasks."], f"dynamic calls: {f['dynamic']}")
check({n for _, n in f["subs"]} == {"tasks", "ui", "nothing"}, f"subscriptions: {f['subs']}")
check(len(f["dynsubs"]) == 1, "variable service list is dynamic")

other = m.extract("modules/Other.qml", "root.call('list')", WRAPPERS)
check(other["methods"] == [], "file-scoped wrapper ignored elsewhere")

issues = m.verify("x.qml", f, REG, {})
msgs = [i.message for i in issues if i.severity == "error"]
check(any('"tasks.missing"' in s for s in msgs), "unknown method is an error")
check(any('"tasks.bogus"' in s for s in msgs), "unknown wrapped method is an error")
check(any("ghost" in s for s in msgs), "unknown service is an error")
check(any('"ui"' in s and "event stream" in s for s in msgs), "subscribing to a service without Subscribe is an error")
check(any('"nothing"' in s for s in msgs), "unknown subscription service is an error")
check(not any('"tasks.list"' in s or '"tasks.create"' in s for s in msgs), "known methods pass")
warns = [i for i in issues if i.severity == "warn"]
check(len(warns) == 3, f"dynamic calls and subscriptions warn: {[w.message for w in warns]}")
quiet = m.verify("x.qml", f, REG, {"x.qml": "reason"})
check(not [i for i in quiet if i.severity == "warn"], "allow-listed file does not warn")

reg = m.load_registry()
check("ipc" in reg and "hello" in reg["ipc"]["methods"], "registry carries the ipc.hello handshake")
data = json.loads(m.REGISTRY.read_text())
check(isinstance(data["protocol"], int), "registry has the protocol version")

if failures:
    print("\n".join("FAIL: " + x for x in failures))
    sys.exit(1)
print("ipc-methods audit: ok")
