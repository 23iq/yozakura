"""Every schema entry is reachable in the settings window, offscreen.

For every schema tab (a category with `sections`, not a hand-written
`page`): the tab opens, its folded More settings card (PageMore: the tab's
advanced rows) unfolds, and every entry that shows on this compositor with
this config (compositor gate, visibleWhen) has its row object on the page:
a row of a card or of the More card. Then the search: an advanced entry is
found from home, and the jump opens its tab's More card on its row
(modules/settings/AGENTS.md, SEARCH). The schema-level half (every entry a
card row or a More row, every labelled one in the search index) is
tests/settings-window.test.cjs.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402
from waits import wait_until  # noqa: E402

env = SettingsEnv("settings-reachable")
h = env.h
failures: list[str] = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
import "../qs/modules/settings/schema/Categories.js" as Categories
import "../qs/modules/settings/SchemaUtil.js" as SchemaUtil
import "../qs/modules/settings/CompositorGate.js" as CompositorGate
Window {
    id: w
    width: 1180; height: 780; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    // schema tabs drawn by SettingsPage
    function schemaTabs() {
        return Categories.categories.filter(c => !c.page && (c.sections || []).length > 0).map(c => c.id);
    }
    // entries of a tab that show now and have no row object on its page
    function missing(id) {
        var cat = Categories.byId(id);
        var page = w.findItem("settingsPage").item;
        var heroIds = (cat.hero && cat.hero.foot) || [];
        var out = [];
        (cat.sections || []).forEach(function (sec) {
            if (!CompositorGate.allows(sec.compositor, YozdService.compositorName))
                return;
            (sec.entries || []).forEach(function (e) {
                if (!SettingsStore.visible(e))
                    return;
                var eid = SchemaUtil.entryId(e);
                if (!w.findItem("settingRow:" + eid, page))
                    out.push(eid + (SchemaUtil.isAdvanced(e, sec) ? " (More)" : "") + (heroIds.indexOf(eid) >= 0 ? " (foot)" : ""));
            });
        });
        return out;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr):
    r = h.eval(win, expr)
    return r.toVariant() if hasattr(r, "toVariant") else r


def sev(expr):
    return h.eval(shell, expr)


tabs = ev("schemaTabs()")
check(len(tabs) > 20, f"{len(tabs)} schema tabs")
opened = 0
for cat in tabs:
    sev(f'select("{cat}")')
    if not env.wait_page(win, 15000):
        check(False, f"{cat}: page built")
        continue
    more = ev('w.findItem("moreSettings", w.findItem("settingsPage").item)')
    if more is not None and h.eval(more, "visible") is True:
        h.eval(more, "open(true)")
        opened += 1
    QTest.qWait(30)
    lost = ev(f'missing("{cat}")')
    check(not lost, f"{cat}: every entry that shows has its row" + (f" (missing: {', '.join(lost)})" if lost else ""))
check(opened > 5, f"{opened} tabs have a More settings card")

# search: an advanced entry is found and its jump opens the More card
sev('select("dock")')
env.wait_page(win)
sev("goHome()")
QTest.qWait(50)
field = ev('w.findItem("settingsSearch")')
target = ev("""(function() {
    var c = Categories.byId("notch");
    var g = SchemaUtil.moreGroups(c)[0];
    return g ? SchemaUtil.entryId(g.entries[0]) : "";
})()""")
check(bool(target), f"the Island tab has an advanced entry ({target})")
label = ev(f'I18n.t(SettingsStore.entryByKey["{target}"].label)')
h.eval(field, f'text = {label!r}')
QTest.qWait(50)
hit = ev(f'w.findItem("settingsHome").results.findIndex(r => r.entryId === "{target}")')
check(hit >= 0, f"search finds the advanced entry by its label ({label})")
ev(f'w.findItem("settingsHome").activateResult({hit})')
check(wait_until(lambda: ev("SettingsStore.highlightedEntry") == target, timeout_ms=8000), "the jump lands on it")
check(sev("currentCategory") == "notch", "...on its tab")
check(ev('w.findItem("moreSettings", w.findItem("settingsPage").item).expanded') is True, "...with the More card open")
check(ev(f'w.findItem("settingRow:{target}", w.findItem("settingsPage").item).activeFocus') is True, "...and its row focused")

if failures:
    print(f"settings-reachable: {len(failures)} failure(s)")
    env.h.exit(1)
print("settings-reachable: ok")
env.h.exit(0)
