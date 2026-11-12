"""Hand-written device pages fit the default window (1180x780), offscreen,
with the device fixtures (tests/lib/device_fixtures.py).

Displays and Keyboard are hand-written pages (they edit a draft / a live
service, not config keys), composed like a converted page (modules/settings/
AGENTS.md, PAGE COMPOSITION): hero, hint, one row of cards at the foot.
settings-fit.test.py checks schema pages only; this checks these: every
card of the row and every item of the hero ends inside the page, the hero
ends above the row, nothing scrolls. Plus the Displays flow on the fitted
page: a scale step and a refresh chip patch the picked monitor's draft,
Apply hands the draft to DisplaysService (its 15 s keep / revert session).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

PAGES = {"displays": "displaysRow", "keyboard": "keyboardRow"}

env = SettingsEnv("settings-devices-fit", devices=True)
h = env.h
failures: list[str] = []


def check(ok: bool, what: str) -> None:
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1180; height: 780; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function page() { var host = findItem("settingsPage"); return host ? host.item : null }
    // {h, row: [top, bottom], cards: [bottoms], heroBottom}
    function measure(rowName) {
        var p = page(), row = findItem(rowName, p);
        if (!p || !row) return null;
        var top = row.mapToItem(p, 0, 0).y;
        var cards = [];
        for (var i = 0; i < row.children.length; i++) {
            var c = row.children[i];
            if (c.visible) cards.push(Math.round(c.mapToItem(p, 0, c.height).y));
        }
        var hint = findItem("heroHint", p);
        return { "h": p.height, "top": Math.round(top), "cards": cards,
                 "hint": hint ? Math.round(hint.mapToItem(p, 0, hint.height).y) : 0,
                 "contentH": p.contentHeight === undefined ? p.height : p.contentHeight };
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr):
    return h.eval(win, expr)


for cat, row in PAGES.items():
    h.eval(shell, f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")
    QTest.qWait(300)
    m = json.loads(ev(f'JSON.stringify(measure("{row}"))'))
    if m is None:
        check(False, f"{cat}: a row of cards ({row})")
        continue
    check(len(m["cards"]) >= 2, f"{cat}: a row of cards ({len(m['cards'])})")
    for b in m["cards"]:
        check(b <= m["h"] + 1, f"{cat}: a card ends inside the page ({b} <= {m['h']})")
    check(m["hint"] <= m["top"], f"{cat}: the hero and its hint end above the row ({m['hint']} <= {m['top']})")
    check(m["contentH"] <= m["h"] + 1, f"{cat}: the page does not scroll")

# the Displays flow on the fitted page
h.eval(shell, 'select("displays")')
env.wait_page(win)
QTest.qWait(200)
page = ev("w.page()")
check(h.eval(page, "dirty") is False, "displays: nothing to apply at first")
h.eval(ev('w.findItem("scaleStep:1.5", w.page())'), "clicked()")
h.eval(ev('w.findItem("refreshChips", w.page())'), "selected(144)")
d = json.loads(h.eval(page, "JSON.stringify(draft[0])"))
check(d["scale"] == 1.5 and d["refresh"] == 144, f"a scale step and a refresh chip patch the picked monitor ({d['scale']}, {d['refresh']})")
check(ev('w.findItem("applyButton", w.page()).enabled') is True, "Apply enables")
h.eval(ev('w.findItem("applyButton", w.page())'), "clicked()")
calls = json.loads(ev("JSON.stringify(DisplaysService.calls)"))
check(len(calls) == 1 and calls[0][0] == "apply" and calls[0][1][0]["scale"] == 1.5, "Apply hands the draft to the service")
check(ev("DisplaysService.pending") is True, "...which starts its keep / revert session")
h.eval(ev('w.findItem("nightToggle", w.page())'), "toggled(true)")
check(ev("NightLightClient.active") is True, "night light turns on live")

if failures:
    print(f"settings-devices-fit: {len(failures)} failure(s)")
    h.exit(1)
print("settings-devices-fit: ok")
h.exit(0)
