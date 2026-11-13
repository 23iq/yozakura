"""Converted settings pages fit the default window (1180x780), offscreen.

A page with a `row` in its schema category (modules/settings/AGENTS.md,
PAGE COMPOSITION) is exactly: the stage (+ side columns), the hint line and
one row of cards of Look.cardRowHeight at the bottom. For every converted
tab this checks, after the page is built: the page does not scroll, every
row card ends inside the page, the stage ends above the row, the side
columns end above the row, and a picture card's strip is one row.

The hand-written fitted pages (category `fitted`: Displays, Keyboard,
About, Changes, on a FittedFrame) are checked the same way: their hero
(`fittedHero`) ends above their row, every row card (`fittedCard`) ends
inside the page. They run with the device fixtures
(tests/lib/device_fixtures.py). Every category with a `row` or `fitted`
must be in CONVERTED, so the list stays true.
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

CONVERTED = [
    "bar", "notch", "dock", "layout", "appearance", "icons-type", "notifications", "osd", "menus", "lockscreen",
    "wallpapers", "launcher", "dashboard", "desktop", "overview", "terminal", "presets", "extras", "mods",
    "voice", "timers", "routines", "ai", "ai-providers", "ai-code", "system", "updates",
    "windows", "power", "network", "bluetooth", "sound", "effects", "input", "specials",
    "displays", "keyboard", "about", "changes",
]
MULTI = ('[{"id": "top", "edge": "top", "style": "classic", "groups": {"start": ["launcher"], "end": ["clock"]}},'
         ' {"id": "rail", "edge": "left", "style": "rail", "groups": {"start": ["launcher"], "end": ["power"]}}]')

env = SettingsEnv("settings-fit", devices=True)
h = env.h
failures: list[str] = []


def check(ok: bool, what: str) -> None:
    if not ok:
        failures.append(what)
        print("FAIL:", what, file=sys.stderr)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.settings.store
import "%s/modules/settings/schema/Categories.js" as Categories
Window {
    id: w
    width: 1180; height: 780; visible: true
    function walk(item, fn) {
        if (!item) return;
        fn(item);
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) walk(kids[i], fn);
    }
    function withRow() { return Categories.categories.filter(c => (c.row || []).length > 0 || c.fitted === true).map(c => c.id) }
    // {scrolls, page h, row cards [name, bottom], stage bottom, row top, sides bottom}
    function measure() {
        var host = null;
        walk(w.contentItem, x => { if (!host && x.objectName === "settingsPage") host = x; });
        var page = host ? host.item : null;
        if (!page) return null;
        var out = { "h": page.height, "contentH": page.contentHeight === undefined ? page.height : page.contentHeight, "cards": [], "stage": -1, "sides": 0, "rowTop": 1e9, "list": page.listForm === true, "stageH": 0, "beside": page.sideOnly === true, "cut": [], "wide": [], "share": (page.category && page.category.bandShare) || 0.24 };
        walk(page, x => {
            var n = String(x.objectName);
            if (((n.indexOf("settingsSection:") === 0 && x.fixed) || x.fittedCard === true) && x.visible) {
                var p = x.mapToItem(page, 0, 0);
                out.cards.push([n, Math.round(p.y + x.height)]);
                out.rowTop = Math.min(out.rowTop, Math.round(p.y));
                // a card of several rows: every row ends inside the card's
                // content box (only a last row that is a list may scroll on)
                var rows = [];
                walk(x, r => { if (String(r.objectName).indexOf("settingRow:") === 0 && r.visible && r.height > 0) rows.push(r); });
                // nothing past the card's right content edge: an inline control
                // whole (not wider than its slot) and inside the card, and no
                // row label wrapped onto three lines
                var right = Math.round(p.x + x.width - (x.padding || 0));
                rows.forEach(r => {
                    walk(r, c => {
                        var cn = String(c.objectName);
                        if (cn === "rowLabel" && c.visible && c.lineCount > 2)
                            out.wide.push([n + " / " + r.objectName + " label lines", c.lineCount, 2]);
                        if (cn !== "rowControl" || !c.visible || !c.item)
                            return;
                        var it = c.item;
                        var e = Math.round(it.mapToItem(page, it.width, 0).x);
                        if (e > right + 1)
                            out.wide.push([n + " / " + r.objectName, e, right]);
                        // (segments cannot shrink; a dropdown elides its value)
                        if (it.dropdown === false && it.width > 0 && it.implicitWidth > it.width + 2)
                            out.wide.push([n + " / " + r.objectName + " squeezed", Math.round(it.implicitWidth), Math.round(it.width)]);
                    });
                });
                if (rows.length > 1) {
                    var foot = Math.round(p.y + x.height - (x.padding || 0));
                    rows.forEach((r, i) => {
                        var b = Math.round(r.mapToItem(page, 0, r.height).y);
                        // the last row may be a list that scrolls on in the card
                        var list = i === rows.length - 1 && (r.type === "custom" || r.type === "list")
                            && Math.round(r.mapToItem(page, 0, 0).y) < foot;
                        if (b > foot + 1 && !list) out.cut.push([n + " / " + r.objectName, b, foot]);
                    });
                }
            }
            if ((n === "pageStage" || x.fittedHero === true) && x.visible) {
                out.stage = Math.max(out.stage, Math.round(x.mapToItem(page, 0, x.height).y));
                out.stageH = x.height;
            }
            if ((n === "heroLeft" || n === "heroRight") && x.visible)
                out.sides = Math.max(out.sides, Math.round(x.mapToItem(page, 0, x.height).y));
        });
        return out;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""".replace("%s", (env.root / "qs").as_uri()))

shell = h.find(win, "shell")
check(sorted(json.loads(h.eval(win, "JSON.stringify(withRow())"))) == sorted(CONVERTED),
      f"the converted categories are {CONVERTED} (a new `row` belongs in CONVERTED)")


def fits(label: str) -> None:
    QTest.qWait(250)
    m = json.loads(h.eval(win, "JSON.stringify(measure())"))
    if m is None:
        check(False, f"{label}: no page")
        return
    check(m["contentH"] <= m["h"] + 1, f"{label}: the page does not scroll ({m['contentH']} > {m['h']})")
    check(len(m["cards"]) > 0, f"{label}: a row of cards")
    for name, got, limit in m["wide"]:
        check(False, f"{label}: {name} is clipped across its card ({got} > {limit})")
    for name, bottom, foot in m["cut"]:
        check(False, f"{label}: {name} is cut by its card ({bottom} > {foot})")
    for name, bottom in m["cards"]:
        check(bottom <= m["h"] + 1, f"{label}: {name} ends inside the page ({bottom} > {m['h']})")
    if m["stage"] >= 0:
        check(m["stage"] <= m["rowTop"], f"{label}: the stage ends above the row ({m['stage']} > {m['rowTop']})")
    if not m["beside"]:
        check(m["sides"] <= m["rowTop"], f"{label}: the side columns end above the row ({m['sides']} > {m['rowTop']})")
    if m["list"]:
        # the list form: a short band, the cards take the rest
        check(m["stageH"] <= m["h"] * (m["share"] + 0.06), f"{label}: the list form's band keeps its share ({m['stageH']})")
        check(m["rowTop"] <= m["h"] * (m["share"] + 0.21), f"{label}: the list form's cards take the rest ({m['rowTop']})")


for cat in CONVERTED:
    h.eval(shell, f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")
    fits(cat)

# several bars: the same row for the picked bar
h.eval(win, f"SettingsStore.set('bar.panels', {MULTI})")
h.eval(shell, 'select("bar")')
check(env.wait_page(win), "bar (several bars): page built")
fits("bar (several bars)")
h.eval(win, "SettingsStore.set('bar.panels', [])")

# the island turned off (a preset, the CLI): its switch is beside the
# stage, the waiting cards stay in the row, dimmed, with one Turn on
h.eval(win, "SettingsStore.set('notch.enabled', false)")
h.eval(shell, 'select("notch")')
check(env.wait_page(win), "island off: page built")
QTest.qWait(200)
on = json.loads(h.eval(win, """JSON.stringify((function() {
    var sw = null, waiting = 0;
    walk(w.contentItem, x => {
        if (String(x.objectName) === "settingRow:notch.enabled" && x.visible) sw = x;
        if ((String(x.objectName) === "sectionWaiting" || String(x.objectName) === "sectionTurnOn") && x.visible) waiting++;
    });
    return { "switch": sw !== null, "waiting": waiting };
})())"""))
check(on["switch"], "island off: the Show the island switch is on the page")
check(on["waiting"] > 0, "island off: the waiting cards stay (dimmed, with one Turn on) instead of vanishing")
h.eval(win, "SettingsStore.set('notch.enabled', true)")
fits("notch (island off and on again)")

if failures:
    print(f"settings-fit: {len(failures)} failure(s)")
    h.exit(1)
print("settings-fit: ok")
h.exit(0)
