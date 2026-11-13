"""Layout probe of the settings window for offscreen tests.

`window(env)` is a QML Window holding a SettingsShell with a `probe()` function
that walks what is on screen and reports, in window coordinates:

* overlaps: pairs of siblings that intersect (cards of a page, rows of a
  card, the header's parts, the stage / hint / cards band, home tiles, a
  tile's name / status and its scene);
* texts that are elided (`truncated`) or painted past their own box or
  past the card they sit in;
* picture-card options that are out of reach (outside their selector and
  not in a scrolling strip);
* the stage: its height against the page, whether it is a desktop stage;
* rows on screen (density, reported).

`problems(m)` turns a probe into readable failures. Used by
tests/settings-fit*.test.py and tests/settings-stability.test.py.
"""
import json
import sys
from pathlib import Path

_WINDOW = """
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.services
import "%s/modules/settings/schema/Categories.js" as Categories
Window {
    id: w
    width: 1180; height: 780; visible: true
    function categoryIds() { return Categories.categories.map(c => c.id) }
    function walk(item, fn) {
        if (!item) return;
        if (fn(item) === false) return;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) walk(kids[i], fn);
    }
    function find(name, from) {
        var found = null;
        walk(from || w.contentItem, x => { if (found) return false; if (x.objectName === name) found = x; });
        return found;
    }
    function shown(it) {
        for (var x = it; x; x = x.parent) if (!x.visible || x.opacity < 0.01) return false;
        return true;
    }
    // window rect of an item (ancestors' scale included)
    function rect(it) {
        var p = it.mapToItem(null, 0, 0), q = it.mapToItem(null, it.width, it.height);
        return [Math.round(p.x), Math.round(p.y), Math.round(q.x - p.x), Math.round(q.y - p.y)];
    }
    // the ancestors that clip (what is past them is not painted)
    function clippers(it) {
        var out = [];
        for (var x = it.parent; x; x = x.parent) if (x.clip) out.push(x);
        return out;
    }
    function meets(a, b) {
        // more than a hairline in both directions
        return a[0] + a[2] > b[0] + 1 && b[0] + b[2] > a[0] + 1 && a[1] + a[3] > b[1] + 1 && b[1] + b[3] > a[1] + 1;
    }
    function pairs(label, list, out) {
        for (var i = 0; i < list.length; i++)
            for (var j = i + 1; j < list.length; j++)
                if (meets(list[i][1], list[j][1]))
                    out.push([label, list[i][0], list[j][0], list[i][1], list[j][1]]);
    }
    function onScreen(r) { return r[1] < w.height && r[1] + r[3] > 0 && r[2] > 0 && r[3] > 0; }
    function cardOf(it) {
        for (var x = it; x; x = x.parent)
            if (String(x.objectName).indexOf("settingsSection:") === 0 || x.fittedCard === true) return x;
        return null;
    }
    function texts(root, out) {
        walk(root, x => {
            if (!x.visible || x.opacity < 0.01) return false;
            if (x.truncated === undefined || x.text === undefined || typeof x.text !== "string" || x.text === "") return;
            if (!shown(x)) return;
            var r = rect(x);
            if (!onScreen(r)) return;
            if (x.truncated)
                out.elided.push([String(x.text).slice(0, 60), r]);
            // past its own box (no wrap, no elide, not clipped)
            if (x.width > 0 && x.wrapMode === Text.NoWrap && x.elide === Text.ElideNone && !x.clip && x.contentWidth > x.width + 2)
                out.outside.push([String(x.text).slice(0, 60), "its box", Math.round(x.contentWidth), Math.round(x.width)]);
            // past the card it sits in (what a clipping parent cuts is not painted)
            var c = cardOf(x);
            if (c) {
                var cr = rect(c);
                var k = r[2] / Math.max(1, x.width);
                var cw = x.contentWidth * k;
                var left = r[0] + (x.horizontalAlignment === Text.AlignRight ? r[2] - Math.min(cw, r[2]) : 0);
                var right = left + Math.min(cw, Math.max(r[2], cw));
                clippers(x).forEach(k => {
                    var kr = rect(k);
                    left = Math.max(left, kr[0]);
                    right = Math.min(right, kr[0] + kr[2]);
                });
                if (right > left && (left < cr[0] - 1 || right > cr[0] + cr[2] + 1))
                    out.outside.push([String(x.text).slice(0, 60), String(c.objectName), [Math.round(left), Math.round(right)], [cr[0], cr[0] + cr[2]]]);
            }
        });
    }
    function probe() {
        var out = { "overlaps": [], "elided": [], "outside": [], "unreachable": [], "stage": null, "rows": 0, "rowsTotal": 0, "home": false, "page": "", "schema": false, "list": false };
        var home = find("settingsHome");
        var atHome = home && home.visible && home.opacity > 0.99;
        if (atHome) {
            out.home = true;
            var tiles = [];
            walk(home, x => {
                var n = String(x.objectName);
                if (n.indexOf("homeTile:") !== 0 || !x.visible) return;
                tiles.push([n, rect(x)]);
                // name / status against the scene (a picture tile draws its
                // scene under everything, behind a scrim: by design)
                var parts = [];
                walk(x, y => {
                    var m = String(y.objectName);
                    if (m === "homeTileScene" && y.visible && y.width > 0 && y.height > 0 && !y.anchors.fill) parts.push(["scene", rect(y)]);
                    if (m === "homeTileStatus" && y.visible) parts.push(["label", rect(y.parent)]);
                });
                pairs(n, parts, out.overlaps);
                return false;
            });
            pairs("home tiles", tiles, out.overlaps);
            texts(home, out);
            return out;
        }
        var host = find("settingsPage");
        var page = host ? host.item : null;
        if (!page) return null;
        out.page = page.category ? page.category.id : "";
        out.schema = !!(page.category && page.category.sections && !page.category.page);
        out.list = page.listForm === true;
        // the header
        var head = [];
        ["backPill", "destinationTitle", "destinationTabs", "pageUndo", "pageReset"].forEach(n => {
            var it = find(n);
            if (it && shown(it) && it.width > 0) head.push([n, rect(it)]);
        });
        pairs("header", head, out.overlaps);
        texts(find("destinationTitle") ? find("destinationTitle").parent : null, out);
        // cards and rows
        var cards = [];
        walk(page, x => {
            if (!x.visible) return false;
            var n = String(x.objectName);
            if (n.indexOf("settingsSection:") === 0 || x.fittedCard === true) {
                var r = rect(x);
                if (r[3] > 0) cards.push([n || "fittedCard", r]);
                var rows = [];
                walk(x, y => {
                    if (!y.visible) return false;
                    var m = String(y.objectName);
                    if (m.indexOf("settingRow:") === 0 && y.height > 0 && y.shown !== false) {
                        var rr = rect(y);
                        rows.push([m, rr]);
                        out.rowsTotal++;
                        // density: rows wholly inside the first screen
                        if (page.contentY === 0 && rr[1] >= 0 && rr[1] + rr[3] <= w.height + 1) out.rows++;
                        return false;
                    }
                });
                pairs(n, rows, out.overlaps);
            }
        });
        pairs("cards", cards, out.overlaps);
        // stage, hint, cards: one band under the other
        var stage = find("pageStage", page);
        var hint = find("heroHint", page);
        var band = [];
        if (stage && stage.active && shown(stage) && stage.height > 0) {
            band.push(["stage", rect(stage)]);
            out.stage = { "h": stage.height, "pageH": page.height, "desktop": page.plainStage === false };
        }
        if (hint && shown(hint) && hint.text !== "") band.push(["hint", rect(hint)]);
        if (cards.length > 0 && page.contentY === 0) {
            var top = Math.min.apply(null, cards.map(c => c[1][1]));
            band.push(["cards", [cards[0][1][0], top, 1, 1]]);
            band.forEach(b => {
                if (b[0] !== "cards" && b[1][1] + b[1][3] > top + 1)
                    out.overlaps.push(["page", b[0], "the first card", b[1], [0, top, 0, 0]]);
            });
        }
        if (band.length > 1 && band[0][0] === "stage" && band[1][0] === "hint")
            pairs("page", band.slice(0, 2), out.overlaps);
        texts(page, out);
        // picture cards: every option inside its selector, or in a strip that scrolls
        walk(page, x => {
            if (!x.visible) return false;
            if (String(x.objectName).indexOf("card:") !== 0 || x.selected === undefined) return;
            var sel = null, strip = false;
            for (var p = x.parent; p; p = p.parent) {
                if (String(p.objectName) === "pictureStrip" && p.interactive) strip = true;
                if (p.options !== undefined && p.selected !== undefined && p.entry !== undefined) { sel = p; break; }
            }
            if (!sel || strip) return false;
            var r = rect(x), sr = rect(sel);
            if (r[0] < sr[0] - 1 || r[0] + r[2] > sr[0] + sr[2] + 1 || r[0] < 0 || r[0] + r[2] > w.width + 1)
                out.unreachable.push([String(x.objectName), r, sr]);
            return false;
        });
        return out;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}
"""


def window(env) -> str:
    """The probe window's QML for a SettingsEnv."""
    return _WINDOW.replace("%s", (env.root / "qs").as_uri())


def problems(m: dict | None, label: str) -> list[str]:
    """Readable failures of one probe."""
    if m is None:
        return [f"{label}: no page"]
    out = []
    for kind, a, b, ra, rb in m["overlaps"]:
        out.append(f"{label}: {kind}: {a} {ra} overlaps {b} {rb}")
    for text, r in m["elided"]:
        out.append(f"{label}: text elided: {text!r} {r}")
    for item in m["outside"]:
        out.append(f"{label}: text painted outside {item[1]}: {item[0]!r} {item[2]} vs {item[3]}")
    for name, r, sr in m["unreachable"]:
        out.append(f"{label}: option out of reach: {name} {r} outside {sr}")
    st = m.get("stage")
    if st and st["h"] > st["pageH"] / 3 + 2:
        out.append(f"{label}: the stage takes more than a third of the page ({st['h']} of {st['pageH']})")
    return out


def settled_probe(h, win, label: str) -> dict | None:
    """A probe of the layout once it has settled: a page still placing a
    picture that just loaded (a row 2 px taller for one polish) is probed
    again 400 ms later; what is still wrong then is a fault (motion between
    frames is settings-stability's job)."""
    from PySide6.QtTest import QTest
    m = json.loads(h.eval(win, "JSON.stringify(probe())"))
    if problems(m, label):
        QTest.qWait(400)
        m = json.loads(h.eval(win, "JSON.stringify(probe())"))
    return m


class Sweep:
    """Walks home and tabs of a probe window and collects failures.

    `sweep = Sweep(env, win)`; `sweep.home(label)`, `sweep.tab(cat, label)`,
    `sweep.all(suffix)` (home and every category); `sweep.failures`.
    """

    DESKTOP = {"bar", "notch", "dock", "desktop", "lockscreen", "notifications", "menus", "windows", "wallpapers"}

    def __init__(self, env, win, settle_ms: int = 250):
        self.env = env
        self.h = env.h
        self.win = win
        self.shell = env.h.find(win, "shell")
        self.settle_ms = settle_ms
        self.failures: list[str] = []
        self.density: dict[str, int] = {}

    def check(self, ok: bool, what: str) -> None:
        if not ok:
            self.failures.append(what)
            print("FAIL:", what, file=sys.stderr)

    def probe(self, label: str, settle_ms: int | None = None) -> dict | None:
        from PySide6.QtTest import QTest
        QTest.qWait(self.settle_ms if settle_ms is None else settle_ms)
        m = settled_probe(self.h, self.win, label)
        for p in problems(m, label):
            self.check(False, p)
        return m

    def home(self, label: str = "home") -> None:
        self.h.eval(self.shell, "goHome()")
        m = self.probe(label, 600)
        self.check(m is not None and m["home"], f"{label}: home shown")

    def tab(self, cat: str, label: str | None = None) -> dict | None:
        label = label or cat
        self.h.eval(self.shell, f'select("{cat}")')
        self.check(self.env.wait_page(self.win), f"{label}: page built")
        m = self.probe(label)
        if m is not None and not m["home"]:
            if m["stage"] is not None:
                self.check(cat in self.DESKTOP or not m["stage"]["desktop"],
                           f"{label}: a desktop stage on a page that is not about the desktop")
            self.density[cat] = m["rows"]
        return m

    def categories(self) -> list[str]:
        return json.loads(self.h.eval(self.win, "JSON.stringify(categoryIds())"))

    def all(self, suffix: str = "") -> None:
        self.home("home" + suffix)
        for cat in self.categories():
            self.tab(cat, cat + suffix)

    def language(self, lang: str) -> None:
        """Switch the window's strings to translations/<lang>.json."""
        strings = (Path(__file__).resolve().parents[2] / "translations" / f"{lang}.json").read_text()
        self.h.eval(self.win, f"I18n.strings = {json.dumps(json.loads(strings), ensure_ascii=False)}")
