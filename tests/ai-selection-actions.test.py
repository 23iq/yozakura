"""Selection results require inspection and an explicit copy; late results are ignored."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-selection-actions")
h.module("Quickshell", {"Placeholder": "QtObject {}"})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command; property bool running: false; property QtObject stdout; signal exited(int exitCode, int exitStatus) }",
    "StdioCollector": "QtObject { property string text; signal streamFinished() }",
})
h.singleton("qs.config", "Config", "QtObject { property var ai: ({selection: {actions: [], output: 'replace', language: 'English'}, prompts: []}) }")
h.singleton("qs.modules.globals", "GlobalStates", "QtObject { property bool assistantVisible: false; function focusedScreenName() { return 'test'; } function toggleAssistant() { assistantVisible = !assistantVisible; } }")
h.singleton("qs.modules.services", "I18n", "QtObject { function t(key) { return key; } }")
h.singleton("qs.modules.services", "Ai", """QtObject {
    property bool accepted: false
    property string noticeError: "unavailable"
    property var callback
    property string lastPrompt: ""
    function runPrompt(prompt, opts, cb) { lastPrompt = prompt; callback = cb; }
    function send(prompt, attachments) { lastPrompt = prompt; return accepted; }
    function askQuick(prompt, attachments) { lastPrompt = prompt; return accepted; }
    function setMode(mode) {}
    function finish(result, err) { callback(result, err); }
}""")
path = h.copy("modules/services/ai/SelectionActions.qml", dest="modules/services/ai", siblings=False)
root = h.load(path, auto_stub=False)
action = "({prompt: 'Rewrite {selection}', label: 'Rewrite', output: 'replace'})"
h.eval(root, "visible = true; text = 'original'; run(" + action + ")")
h.eval(root, "Ai.finish('```text\\nnew text\\n```', '')")
assert h.eval(root, "visible") is True
assert h.eval(root, "hasResult") is True
assert h.eval(root, "result") == "new text"
assert h.eval(root, "output.running") is False
h.eval(root, "copyResult()")
assert h.eval(root, "JSON.stringify(output.command)") == '["wl-copy","--","new text"]'
assert h.eval(root, "visible") is True
h.eval(root, "output.exited(1, 0)")
assert h.eval(root, "error") == "ai.selection_copy_failed"
assert h.eval(root, "hasResult") is True
assert h.eval(root, "openResult()") is False
assert h.eval(root, "error") == "unavailable"
assert h.eval(root, "visible") is True
h.eval(root, "Ai.accepted = true")
assert h.eval(root, "openResult()") is True
assert h.eval(root, "visible") is False
# Rejected shortcuts keep the selection and the failure visible.
for output in ("sidebar", "quickask"):
    h.eval(root, "visible = true; run({prompt: 'Explain {selection}', output: '" + output + "'})")
    # Accepted currently; reset and repeat.
    h.eval(root, "Ai.accepted = false; visible = true; run({prompt: 'Explain {selection}', output: '" + output + "'})")
    assert h.eval(root, "visible") is True
    assert h.eval(root, "error") == "unavailable"
h.eval(root, "visible = true; ask('Why?')")
assert h.eval(root, "visible") is True
assert h.eval(root, "error") == "unavailable"
# Closing and reopening invalidates the previous callback.
h.eval(root, "run(" + action + "); close(); visible = true; Ai.finish('stale', '')")
assert h.eval(root, "hasResult") is False
assert h.eval(root, "visible") is True
h.eval(root, "run(" + action + "); Ai.finish('', 'generation failed')")
assert h.eval(root, "error") == "generation failed"
assert h.eval(root, "working") is False
assert h.eval(root, "visible") is True
print("PASS: selection preview, explicit copy, rejection and stale response")
