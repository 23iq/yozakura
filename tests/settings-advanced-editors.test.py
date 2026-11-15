"""The editors that only `advanced` schema entries use (rows of a tab's More
card, PageMore, never of its cards) still build: each one is built as a row
of a More card, from its real schema entry (SchemaUtil.isAdvanced), offscreen,
without QML errors, and is given a size.
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

# every custom editor no card row uses, with the first advanced entry naming
# it, in a one-section category of its own (its section's flags kept, the
# visibility conditions dropped: the row must show to build its editor)
FIND = r"""
const {loadLibrary} = require('./tests/lib/qmljs.cjs');
const C = loadLibrary('modules/settings/schema/Categories.js');
const U = loadLibrary('modules/settings/SchemaUtil.js');
const shown = new Set(), adv = {};
for (const x of U.flatten(C.categories)) {
    const c = x.entry.component;
    if (!c) continue;
    if (U.inCards(x.entry, x.section)) shown.add(c);
    else if (U.isAdvanced(x.entry, x.section) && !(c in adv)) adv[c] = x;
}
const out = Object.keys(adv).filter(c => !shown.has(c)).map(c => {
    const x = adv[c];
    const entry = Object.assign({}, x.entry);
    delete entry.visibleWhen;
    delete entry.compositor;
    const section = Object.assign({}, x.section, { id: x.section.id, entries: [entry] });
    delete section.compositor;
    delete section.toggle;
    const category = { id: "adv-" + c, sections: [section] };
    if (U.moreGroups(category).length !== 1) throw new Error(c + ": not a More card row");
    return { name: c, id: U.entryId(entry), category: category };
});
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
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 900; height: 1400; visible: true
    property var editors: []
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    // the Loader of a custom editor (RowControls) under `from`
    function findEditor(file, from) {
        if (from.source !== undefined && String(from.source).endsWith("/" + file + ".qml")) return from;
        var kids = from.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findEditor(file, kids[i]); if (f) return f; }
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
                delegate: PageMore {
                    required property var modelData
                    objectName: "advMore:" + modelData.name
                    width: col.width
                    category: modelData.category
                }
            }
        }
    }
}""")
h.eval(win, "editors = " + json.dumps(editors))

for e in editors:
    name = e["name"]
    more = f'w.findItem("advMore:{name}")'
    check(h.eval(win, f"{more}.count") == 1, f"{name}: one row in its More card")
    row = h.eval(win, f"{more}.rowFor({json.dumps(e['id'])})")
    check(row is not None and h.eval(win, f"{more}.expanded") is True, f"{name}: the card opens on its row")
    if row is None:
        continue
    ed = f'w.findEditor("{name}", {more})'
    check(wait_until(lambda ed=ed: h.eval(win, f"!!{ed} && ({ed}.status === 1 || {ed}.status === 3)"), timeout_ms=8000),
          f"{name}: loaded")
    status = h.eval(win, f"{ed} ? {ed}.status : 0")
    check(status == 1, f"{name}: builds ({['null', 'ready', 'loading', 'error'][status]})")
    if status == 1:
        check(h.eval(win, f"{ed}.item.implicitHeight") > 0, f"{name}: has a height")

check(not errors, "no QML errors:\n  " + "\n  ".join(errors[:20]))
if failures:
    print(f"settings-advanced-editors: {len(failures)} failure(s)")
    h.exit(1)
print("settings-advanced-editors: ok")
h.exit(0)
