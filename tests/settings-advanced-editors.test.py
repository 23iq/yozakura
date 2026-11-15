"""The editors that only `advanced` schema entries use (shown in a tab's More
card, not as rows of its cards) still build: each one is created from
Registry.EDITORS with its real schema entry, offscreen, without QML errors,
and is given a size.
"""
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from settings_env import SettingsEnv  # noqa: E402
from waits import wait_until  # noqa: E402

REPO = Path(__file__).resolve().parent.parent

# every custom editor no window row uses, with the first advanced entry naming it
FIND = r"""
const {loadLibrary} = require('./tests/lib/qmljs.cjs');
const C = loadLibrary('modules/settings/schema/Categories.js');
const U = loadLibrary('modules/settings/SchemaUtil.js');
const R = loadLibrary('modules/settings/Registry.js');
const shown = new Set(), adv = {};
for (const x of U.flatten(C.categories)) {
    const c = x.entry.component;
    if (!c) continue;
    if (U.inWindow(x.entry, x.section)) shown.add(c);
    else if (!(c in adv)) adv[c] = x.entry;
}
const out = Object.keys(adv).filter(c => !shown.has(c)).map(c => ({ name: c, url: R.EDITORS[c], entry: adv[c] }));
console.log(JSON.stringify(out));
"""
editors = json.loads(subprocess.run(["node", "-e", FIND], cwd=REPO, check=True, capture_output=True, text=True).stdout)

env = SettingsEnv("settings-advanced-editors")
h = env.h
failures: list[str] = []
errors: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "Unable to assign",
                              "failed to load", "Error:")):
        errors.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


qInstallMessageHandler(_capture)


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


check(len(editors) >= 5, f"advanced-only editors found ({[e['name'] for e in editors]})")

win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.services
import qs.modules.settings.store
Window {
    id: w
    width: 900; height: 1400; visible: true
    property var editors: []
    property string base: ""
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    Flickable {
        anchors.fill: parent
        contentHeight: col.height
        Column {
            id: col
            width: w.width
            Repeater {
                model: w.editors
                delegate: Loader {
                    required property var modelData
                    objectName: "advEditor:" + modelData.name
                    width: col.width
                    onLoaded: {
                        if ("entry" in item)
                            item.entry = modelData.entry;
                    }
                    Component.onCompleted: setSource(w.base + modelData.url)
                }
            }
        }
    }
}""")
h.eval(win, "base = " + json.dumps((h.root / "qs/modules/settings").as_uri() + "/"))
h.eval(win, "editors = " + json.dumps(editors))

for e in editors:
    name = e["name"]
    check(wait_until(lambda n=name: h.eval(win, f'w.findItem("advEditor:{n}").status') in (1, 3), timeout_ms=8000),
          f"{name}: loaded")
    status = h.eval(win, f'w.findItem("advEditor:{name}").status')
    check(status == 1, f"{name}: builds ({['null', 'ready', 'loading', 'error'][status]})")
    if status == 1:
        check(h.eval(win, f'w.findItem("advEditor:{name}").item.implicitHeight') > 0, f"{name}: has a height")

check(not errors, "no QML errors:\n  " + "\n  ".join(errors[:20]))
if failures:
    print(f"settings-advanced-editors: {len(failures)} failure(s)")
    h.exit(1)
print("settings-advanced-editors: ok")
h.exit(0)
