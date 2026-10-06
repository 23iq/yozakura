"""Key aliases on the first config load (config/AliasGate.qml + ConfigFile.qml).

Two ConfigFiles touched by one alias (bar.activities -> notch.activities)
wait for each other, migrate, then validate and write back; a file no alias
touches validates at once; a missing gated file does not block the others.
FileView is stubbed as in config-adapters.test.py.
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


h = Harness("key-alias-gate")
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command: []; property bool running: false; signal exited(int exitCode, int exitStatus) }",
    "FileViewError": "QtObject { enum Value { Success, Unknown, FileNotFound, PermissionDenied, NotAFile } }",
    "FileView": """QtObject {
    property string path
    property bool atomicWrites
    property bool watchChanges
    property QtObject adapter
    property string content: ""
    signal loaded
    signal loadFailed(var error)
    signal fileChanged
    signal adapterUpdated
    function text() { return content; }
    function setText(t) { content = t; }
    function reload() {}
    function writeAdapter() {}
}""",
})
h.copy("config/ConfigFile.qml")
h.copy("config/AliasGate.qml")

SCENE = """import QtQuick
QtObject {
    id: store
    property string configDir: "/cfg"
    property string presetDir: "/preset"
    property bool pauseAutoSave: false
    property AliasGate aliasGate: AliasGate {
        aliases: [{ "from": "bar.activities", "to": "notch.activities" }]
    }
    property ConfigFile bar: ConfigFile {
        store: store; name: "bar"; adapter: QtObject {}
        defaults: ({ "position": "top" })
    }
    property ConfigFile notch: ConfigFile {
        store: store; name: "notch"; adapter: QtObject {}
        defaults: ({ "activities": { "maxVisible": 3 }, "theme": "default" })
    }
    property ConfigFile dock: ConfigFile {
        store: store; name: "dock"; adapter: QtObject {}
        defaults: ({ "size": 1 })
    }
}"""

s = h.load(SCENE, auto_stub=False)
bar, notch, dock = (h.eval(s, n) for n in ("bar", "notch", "dock"))
h.eval(dock, "content = JSON.stringify({ size: 2 }); loaded()")
check(h.eval(dock, "ready") is True, "a file no alias touches validates at once")
h.eval(bar, "content = JSON.stringify({ position: 'left', activities: { maxVisible: 6 } }); loaded()")
check(h.eval(bar, "ready") is False, "a gated file waits for the other files of its aliases")
h.eval(notch, "content = JSON.stringify({ theme: 'x' }); loaded()")
check(h.eval(bar, "ready") is True and h.eval(notch, "ready") is True, "both validate once all arrived")
check(json.loads(h.eval(notch, "content")) == {"activities": {"maxVisible": 6}, "theme": "x"},
      "the user's value lands on the new key and is written back")
check(json.loads(h.eval(bar, "content")) == {"position": "left"}, "the old key is removed from its file")

s2 = h.load(SCENE, auto_stub=False)
bar2, notch2 = h.eval(s2, "bar"), h.eval(s2, "notch")
h.eval(bar2, "content = JSON.stringify({ position: 'left', activities: { maxVisible: 6 } }); loaded()")
h.eval(notch2, "loadFailed(2)")  # FileNotFound: the preset/defaults copy follows
check(h.eval(bar2, "ready") is True, "a missing gated file does not block the others")
check(json.loads(h.eval(bar2, "content")) == {"position": "left"}, "…and validation still runs")

if failures:
    print(f"\n{len(failures)} failure(s)")
    sys.exit(1)
print("\nall key-alias gate checks passed")
