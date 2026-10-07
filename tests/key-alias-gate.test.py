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
    # The preset copy ("cp -n") succeeds for /preset-ok/ and fails otherwise.
    "Process": """QtObject {
    property var command: []
    property bool running: false
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: {
        if (running && command.indexOf("-n") !== -1)
            exited(String(command[3]).indexOf("/preset-ok/") === 0 ? 0 : 1, 0);
    }
}""",
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
check(h.eval(notch2, "ready") is True, "missing destination is initialized by the gate")
check(json.loads(h.eval(notch2, "content") or "{}") == {"activities": {"maxVisible": 6}, "theme": "default"},
      "missing destination persists migrated values with defaults")

upgrade = h.load(SCENE.replace('aliases: [{ "from": "bar.activities", "to": "notch.activities" }]',
    'aliases: [{ "from": "notch.osd", "to": "layout.osd.style", transform: v => v ? "island" : undefined }]')
    .replace('property ConfigFile dock:', 'property ConfigFile layout: ConfigFile { store: store; name: "layout"; adapter: QtObject {} defaults: ({ osd: { style: "pill", timeout: 2500 } }) }\n    property ConfigFile dock:'), auto_stub=False)
h.eval(h.eval(upgrade, "layout"), "loadFailed(2)")
h.eval(h.eval(upgrade, "notch"), "content = JSON.stringify({ osd: true }); loaded()")
check(json.loads(h.eval(h.eval(upgrade, "layout"), "content") or "{}") == {"osd": {"style": "island", "timeout": 2500}},
      "normal upgrade without layout.json preserves the island OSD preference")

# A missing destination that a preset provides keeps the preset and the migrated value.
preset = h.load(SCENE.replace('"/preset"', '"/preset-ok"'), auto_stub=False)
h.eval(h.eval(preset, "bar"), "content = JSON.stringify({ position: 'left', activities: { maxVisible: 6 } }); loaded()")
pn = h.eval(preset, "notch")
h.eval(pn, "loadFailed(2)")
check(json.loads(h.eval(pn, "JSON.stringify(pendingOverlay)")) == {"activities": {"maxVisible": 6}},
      "the preset copy is tried first, the migrated values wait to be laid over it")
h.eval(pn, "content = JSON.stringify({ theme: 'preset', activities: { maxVisible: 1 } }); loaded()")
check(json.loads(h.eval(pn, "content")) == {"theme": "preset", "activities": {"maxVisible": 6}},
      "the preset's values stay and the migrated value wins")

malformed = h.load(SCENE, auto_stub=False)
bad_notch = h.eval(malformed, "notch")
h.eval(h.eval(malformed, "bar"), "content = JSON.stringify({ activities: { maxVisible: 6 } }); loaded()")
h.eval(bad_notch, "content = '{invalid'; loaded()")
check(h.eval(bad_notch, "content") == "{invalid", "a malformed destination is not overwritten by migration")
check(h.eval(bad_notch, "broken") is True and h.eval(bad_notch, "quarantine.running") is True,
      "a malformed destination is quarantined before replacement")
h.eval(bad_notch, "quarantine.exited(0, 0)")
check(json.loads(h.eval(bad_notch, "content")) == {"activities": {"maxVisible": 3}, "theme": "default"},
      "malformed destination replacement still waits for a successful backup")

if failures:
    print(f"\n{len(failures)} failure(s)")
    sys.exit(1)
print("\nall key-alias gate checks passed")
