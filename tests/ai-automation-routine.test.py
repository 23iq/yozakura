"""AI automations, offscreen: the "routine" output runs the saved routine
through RoutinesService (no template expansion, no model), a prompt output
still goes to the model, and an offered routine automation runs only
after the notification action. Real modules/services/ai/AiAutomations.qml
and Automations.js with stubbed services.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-automation-routine")
h.module("qs.config", {"Config": """pragma Singleton
QtObject {
    property QtObject ai: QtObject { property var automations: [] }
}"""})
h.module("qs.modules.globals", {"GlobalStates": """pragma Singleton
QtObject { property bool assistantVisible: false; function toggleAssistant() {} }"""})
h.module("qs.modules.services.activities", {"ActivityService": """pragma Singleton
QtObject { property var transfers: [] }"""})
h.module("qs.modules.services", {
    "Ai": """pragma Singleton
QtObject {
    property var log: []
    function expandTemplate(p, vars, cb) { log = log.concat(["expand:" + p]); cb(p) }
    function runPrompt(p, opts, cb) { log = log.concat(["prompt:" + p]) }
    function askQuick(p, a) { log = log.concat(["quick:" + p]) }
    function send(p, a) {}
    function setSpace(s) {}
    function _ensureInit() {}
}""",
    "RoutinesService": """pragma Singleton
QtObject {
    property var runs: []
    function run(id, cb) { runs = runs.concat([id]) }
}""",
    "I18n": """pragma Singleton
QtObject { function t(k) { return k } }""",
    "StateService": """pragma Singleton
QtObject { property bool initialized: false; function get(k, d) { return d } function set(k, v) {} }""",
    "BackendService": """pragma Singleton
QtObject { function addSubscription(s, cb) { return 1 } function removeSubscription(id) {} }""",
    "Screenshot": """pragma Singleton
QtObject { signal imageSaved(string path) }""",
})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command: []; property bool running: false; property var stdout; signal exited(int code, int status) }",
    "StdioCollector": "QtObject { property string text: ''; signal streamFinished() }",
})
h.module("Quickshell", {"Quickshell": "pragma Singleton\nQtObject {}"})
h.copy("modules/services/ai/AiAutomations.qml", "qs/modules/services/ai")

root = h.load(h.write("""
import QtQuick
import qs.modules.services
Item {
    AiAutomations { id: auto; objectName: "auto"; clock.running: false; login.running: false }
    function runs() { return JSON.stringify(RoutinesService.runs) }
    function log() { return JSON.stringify(Ai.log) }
}""", dest="qs/modules/services/ai"))
auto = h.find(root, "auto")


def ev(expr):
    return h.eval(root, expr)


routine = '{"id": "a", "name": "Wake", "enabled": true, "trigger": {"type": "login"}, "output": "routine", "routine": "morning", "offer": false}'
ev(f"auto.execute({routine}, {{}}, [])")
assert ev("runs()") == '["morning"]', ev("runs()")
assert ev("log()") == "[]", "a routine automation never reaches the model: " + ev("log()")

prompt = '{"id": "b", "name": "Brief", "enabled": true, "trigger": {"type": "login"}, "output": "notify", "prompt": "hi", "offer": false}'
ev(f"auto.execute({prompt}, {{}}, [])")
assert ev("log()") == '["expand:hi","prompt:hi"]', ev("log()")
assert ev("runs()") == '["morning"]'

# Offered: nothing runs until the notification action is chosen.
offered = routine.replace('"offer": false', '"offer": true')
ev(f"auto.trigger({offered}, {{}}, [])")
assert ev("runs()") == '["morning"]', "offer waits for the click"

print("ai-automation-routine: ok")
