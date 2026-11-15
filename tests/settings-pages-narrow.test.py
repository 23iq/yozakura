"""Hand-written page content that must reflow, offscreen with the device
fixtures (tests/lib/device_fixtures.py):

* at the window's minimum (640x480, Russian strings): the Network,
  Bluetooth and Effects bands keep their words clear of their big tile
  (the tile takes its own width; the sides stack); Bluetooth keeps its
  state line inside the band; the Mods band's state never runs under its
  actions; the Presets strip card stands under the hero, never over it;
* Keyboard at 1600x1000: the "Active" chip of a layout never reaches its
  variant dropdown;
* Changes: every reset button sits in one column, with or without a jump
  after it.
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

# the fit tests' fonts: pinned, and every kit text 20 % wider
env = SettingsEnv("settings-pages-narrow", devices=True, text_wider=0.2, pin_fonts=True)
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
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 640; height: 480; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1) kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function findAll(prefix, from) {
        var out = [];
        function walk(it) {
            if (String(it.objectName).indexOf(prefix) === 0 && it.visible) out.push(it);
            var kids = it.children || [];
            if (it.contentItem && it.contentItem !== it && kids.indexOf(it.contentItem) === -1) kids = kids.concat([it.contentItem]);
            for (var i = 0; i < kids.length; i++) walk(kids[i]);
        }
        walk(from || w.contentItem);
        return out;
    }
    // an item's rect in the window
    function box(it) {
        var p = it.mapToItem(null, 0, 0);
        return {"x": p.x, "y": p.y, "w": it.width, "h": it.height};
    }
    // the page shown now (kept pages hold the same names)
    function page() { var host = findItem("settingsPage"); return host ? host.item : null }
    function boxOf(name) { var it = findItem(name, page()); return it && it.visible ? box(it) : null }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")
strings = (Path(__file__).resolve().parents[1] / "translations" / "ru.json").read_text()
h.eval(win, f"I18n.strings = Object.assign({{}}, I18n.strings, {json.dumps(json.loads(strings), ensure_ascii=False)})")


def ev(expr):
    return h.eval(win, expr)


def box(name):
    raw = ev(f"JSON.stringify(boxOf({json.dumps(name)}))")
    return json.loads(raw) if raw else None


def apart(a, b) -> bool:
    """Two rects that do not overlap (1 px of rounding allowed)."""
    return a["x"] + a["w"] <= b["x"] + 1 or b["x"] + b["w"] <= a["x"] + 1 \
        or a["y"] + a["h"] <= b["y"] + 1 or b["y"] + b["h"] <= a["y"] + 1


def inside(a, b) -> bool:
    return a["x"] >= b["x"] - 1 and a["y"] >= b["y"] - 1 \
        and a["x"] + a["w"] <= b["x"] + b["w"] + 1 and a["y"] + a["h"] <= b["y"] + b["h"] + 1


def visit(cat):
    h.eval(shell, f"select({json.dumps(cat)})")
    env.wait_page(win)
    QTest.qWait(500)


visit("network")
name, tile = box("networkName"), box("wifiTile")
check(name and tile and apart(name, tile), f"network (640, ru): the name clear of the Wi-Fi tile ({name}, {tile})")

visit("bluetooth")
state, tile, band = box("bluetoothState"), box("bluetoothTile"), box("bluetoothBand")
check(state and tile and apart(state, tile), f"bluetooth (640, ru): the state clear of the tile ({state}, {tile})")
check(state and band and inside(state, band), f"bluetooth (640, ru): the state line inside the band ({state}, {band})")

visit("effects")
sides, tile = box("effectsSides"), box("effectsTile")
check(sides and tile and apart(sides, tile), f"effects (640, ru): the presets clear of the tile ({sides}, {tile})")

visit("mods")
state, bypass = box("modsBandState"), box("modsBypass")
check(state and bypass and apart(state, bypass), f"mods (640, ru): the band's state clear of its actions ({state}, {bypass})")

visit("presets")
strip = box("settingsSection:presets_gallery")
for part in ("pageStage", "presetSide"):
    b = box(part)
    check(b and strip and apart(b, strip), f"presets (640, ru): the strip card under the {part}, not over it ({b}, {strip})")

# Keyboard › Layouts, wide window: the chip and the dropdown of a row
win.resize(1600, 1000)
QTest.qWait(300)
visit("keyboard")
chip, combo = box("layoutActive"), box("variantCombo")
check(chip is not None and combo is not None, "keyboard (1600): an active layout row with its variant dropdown")
if chip and combo:
    check(apart(chip, combo), f"keyboard (1600): the Active chip clear of the variant dropdown ({chip}, {combo})")

# Changes: one reset column, whether a row has a jump or not
ev("SettingsStore.set('bar.compact', !Config.bar.compact)")
QTest.qWait(1700)
ev("SettingsStore.set('voice.language', 'es')")
QTest.qWait(1700)
visit("changes")
ev("""(function() {
    var rows = findAll("changeRow:", findItem("changesList", page()));
    if (rows.length > 0) rows[0].change = Object.assign({}, rows[0].change, {"jump": false});
})()""")
QTest.qWait(300)
xs = json.loads(ev("""JSON.stringify(findAll("changeReset", findItem("changesList", page())).map(function (b) {
    return Math.round(b.mapToItem(null, 0, 0).x);
}))"""))
check(len(xs) >= 2, f"changes: a reset per changed setting ({len(xs)})")
check(len(set(xs)) == 1, f"changes: every reset in one column ({sorted(set(xs))})")

if failures:
    print("\n".join("FAIL: " + f for f in failures))
    print(f"settings-pages-narrow: {len(failures)} failure(s)")
    env.h.exit(1)
print("settings-pages-narrow: ok")
env.h.exit(0)
