"""ConfigFile.qml: per-domain auto-save pause and free-form maps on load.

While a staged settings change waits for Apply/Discard only the staged
domains hold their edits back (store.autoSavePausedFor(name)); an edit to
another domain is written. A store without autoSavePausedFor keeps the old
all-domains pauseAutoSave. The first load keeps the user's keys inside a
free-form map (compositor.motionOverrides) and does not rewrite the file.
FileView is stubbed as in key-alias-gate.test.py.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

failures: list[str] = []


def check(ok, msg):
    print(("PASS " if ok else "FAIL ") + msg)
    if not ok:
        failures.append(msg)


h = Harness("config-file-autosave")
h.module("Quickshell.Io", {
    "Process": """QtObject {
    property var command: []
    property bool running: false
    signal exited(int exitCode, int exitStatus)
}""",
    "FileViewError": "QtObject { enum Value { Success, Unknown, FileNotFound, PermissionDenied, NotAFile } }",
    "FileView": """QtObject {
    property string path
    property bool atomicWrites
    property bool watchChanges
    property QtObject adapter
    property string content: ""
    property int writes: 0
    property int setTexts: 0
    signal loaded
    signal loadFailed(var error)
    signal fileChanged
    signal adapterUpdated
    function text() { return content; }
    function setText(t) { content = t; setTexts++; }
    function reload() {}
    function writeAdapter() { writes++; }
}""",
})
h.copy("config/JsonUtil.js")
h.copy("config/JsonUtil.js", dest="config")
h.copy("config/ConfigFile.qml")

SCENE = """import QtQuick
QtObject {
    id: store
    property string configDir: "/cfg"
    property string presetDir: "/preset"
    property bool pauseAutoSave: false
    property var pausedDomains: []
    function autoSavePausedFor(name) { return pausedDomains.indexOf(name) !== -1; }
    property ConfigFile bar: ConfigFile {
        store: store; name: "bar"; adapter: QtObject {}
        defaults: ({ "position": "top" })
    }
    property ConfigFile ai: ConfigFile {
        store: store; name: "ai"; adapter: QtObject {}
        defaults: ({ "model": "x" })
    }
    property ConfigFile compositor: ConfigFile {
        store: store; name: "compositor"; adapter: QtObject {}
        defaults: ({ "gapsIn": 4, "motionOverrides": {} })
    }
}"""

s = h.load(SCENE, auto_stub=False)
bar, ai, comp = (h.eval(s, n) for n in ("bar", "ai", "compositor"))
h.eval(bar, "content = JSON.stringify({ position: 'left' }); loaded()")
h.eval(ai, "content = JSON.stringify({ model: 'y' }); loaded()")
user_comp = {"gapsIn": 6, "motionOverrides": {"windows": {"curve": "snappy", "speed": 3}}}
h.eval(comp, f"content = {json.dumps(json.dumps(user_comp))}; loaded()")
check(all(h.eval(f, "ready") is True for f in (bar, ai, comp)), "all files loaded")
check(json.loads(h.eval(comp, "content")) == user_comp, "motionOverrides survives the first-load validation")
check(h.eval(comp, "setTexts") == 0, "an unchanged free-form map does not rewrite the file")

# Shell settings staged (bar): bar waits, ai is written.
h.eval(s, "pausedDomains = ['bar']")
h.eval(bar, "adapterUpdated()")
h.eval(ai, "adapterUpdated()")
check(h.eval(bar, "writes") == 0, "an edit of a staged domain waits for Apply")
check(h.eval(ai, "writes") == 1, "an edit of another domain is written while settings are staged")
check(h.eval(bar, "autoSave(), writes") == 0, "a pending auto-save of a staged domain stays held")

# Nothing staged: every edit is written.
h.eval(s, "pausedDomains = []")
h.eval(bar, "adapterUpdated()")
check(h.eval(bar, "writes") == 1, "after Apply/Discard edits are written again")

# A store without autoSavePausedFor: pauseAutoSave pauses every domain.
legacy = h.load(SCENE.replace("function autoSavePausedFor(name) { return pausedDomains.indexOf(name) !== -1; }", ""),
                auto_stub=False)
lb, la = h.eval(legacy, "bar"), h.eval(legacy, "ai")
h.eval(lb, "content = JSON.stringify({ position: 'left' }); loaded()")
h.eval(la, "content = JSON.stringify({ model: 'y' }); loaded()")
h.eval(legacy, "pauseAutoSave = true")
h.eval(lb, "adapterUpdated()")
h.eval(la, "adapterUpdated()")
check(h.eval(lb, "writes") == 0 and h.eval(la, "writes") == 0, "pauseAutoSave alone still pauses every domain")

if failures:
    print(f"config-file-autosave: {len(failures)} failure(s)")
    sys.exit(1)
print("config-file-autosave: PASS")
