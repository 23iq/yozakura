"""Simple / All settings view and greyed-row notes, offscreen.

* Simple (general.settingsShowAll false) hides `advanced` rows and a
  section left empty; the page footer counts them and switches to All;
  the sidebar ViewToggle flips the view; a changed advanced row stays shown.
* A search jump (page.reveal) shows an advanced row in Simple.
* A greyed row explains itself (DisabledNote) and [Turn on] flips the one
  switch that decides it; an `invert` toggle shows on for false.
* layout / notifications / performance edits are staged (Discard covers
  them), and GlobalStates restores nested JsonObjects in place.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from qmlharness import REPO  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("settings-simple")
h = env.h

win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.services
Window {
    id: w
    width: 1100; height: 900; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function toggle(key, advanced, extra) {
        var e = { "key": key, "type": "toggle", "label": "prefs.bar.compact", "advanced": advanced };
        for (var k in extra || {}) e[k] = extra[k];
        return e;
    }
    SettingsPage {
        objectName: "page"
        width: parent.width; height: parent.height - 60
        category: ({
            "id": "demo", "icon": "gear", "title": "prefs.cat.bar",
            "sections": [
                { "id": "main", "title": "prefs.cat.bar", "entries": [
                    w.toggle("notch.disableHoverExpansion", false, { "invert": true, "label": "prefs.notch.media_panel" }),
                    w.toggle("notch.visualizer", false, { "enabledWhen": { "key": "notch.disableHoverExpansion", "equals": false } }),
                    w.toggle("bar.frameEnabled", true)] },
                { "id": "expert", "title": "prefs.cat.dock", "entries": [w.toggle("bar.availableOnFullscreen", true)] }
            ]
        })
    }
    ViewToggle { objectName: "toggle"; y: parent.height - 50; width: 300 }
}""")
page = h.find(win, "page")


def ev(expr: str, obj=None):
    return h.eval(obj or win, expr)


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)
    print("PASS", what)


def shown(name: str) -> bool:
    return bool(ev(f'(function(){{ var r = findItem("settingRow:{name}"); return r !== null && r.shown; }})()'))


QTest.qWait(250)
check(ev("SettingsStore.showAll") is False, "Simple is the default view")
check(shown("notch.disableHoverExpansion"), "an essential row shows in Simple")
check(not shown("bar.frameEnabled"), "an advanced row hides in Simple")
check(ev('findItem("settingsSection:expert").visible') is False, "a section of advanced rows only hides")
check(h.eval(page, "simpleHidden") == 2, "the page counts the hidden rows")
check(ev('findItem("simpleFooter").visible') is True, "the footer offers All")

# A search jump reveals one advanced row
h.eval(page, 'reveal("main", "bar.frameEnabled")')
QTest.qWait(80)
check(shown("bar.frameEnabled"), "a search jump shows the advanced row in Simple")
check(h.eval(page, "simpleHidden") == 1, "...and the footer count follows")
ev("SettingsStore.clearRevealed()")

# The footer switches to All, the toggle back to Simple
ev('findItem("simpleShowAll").clicked()')
QTest.qWait(80)
check(ev("Config.general.settingsShowAll") is True, "Show all writes general.settingsShowAll")
check(shown("bar.frameEnabled") and ev('findItem("settingsSection:expert").visible') is True, "All shows every row")
check(ev('findItem("simpleFooter").visible') is False, "no footer in All")
ev('findItem("toggle").clicked()')
QTest.qWait(80)
check(ev("SettingsStore.showAll") is False, "the sidebar toggle returns to Simple")

# A changed advanced row stays in sight
fs0 = ev("Config.bar.availableOnFullscreen")
ev(f"SettingsStore.set('bar.availableOnFullscreen', {str(not fs0).lower()})")
QTest.qWait(80)
check(ev('findItem("settingsSection:expert").visible') is True, "a changed advanced row shows in Simple")
ev(f"SettingsStore.set('bar.availableOnFullscreen', {str(fs0).lower()})")

# Inverted toggle + DisabledNote
ev("SettingsStore.set('notch.disableHoverExpansion', true)")
QTest.qWait(80)
row = 'findItem("settingRow:notch.visualizer")'
check(ev(f"{row}.active") is False, "a gated row is greyed")
note = f'findItem("disabledNote", {row})'
check(ev(f"{note}.visible") is True, "...and shows its note")
check(ev(f'findItem("disabledReason", {row}).text') == "Needs “Media panel” on", "the note names the switch")
check(ev(f'findItem("disabledFix", {row}).visible') is True, "...and offers to turn it on")
ev(f'findItem("disabledFix", {row}).clicked()')
QTest.qWait(80)
check(ev("Config.notch.disableHoverExpansion") is False, "Turn on writes the inverted key")
check(ev(f"{row}.active") is True and ev(f"{note}.visible") is False, "the row is live again, no note")

# layout / notifications / performance are staged now
check(all(ev(f'SettingsStore.isStaged("{d}")') for d in ("layout", "notifications", "performance")),
      "layout, notifications and performance edits are staged")

# GlobalStates restores nested JsonObjects field by field (real function)
src = (REPO / "modules/globals/GlobalStates.qml").read_text()
fn = re.search(r"    function _restoreValue\(holder, prop, val\) \{.*?\n    \}\n", src, re.S).group(0)
probe = env.load("""
import QtQuick
QtObject {
    id: gs
    property QtObject cfg: QtObject {
        objectName: "domain"
        property QtObject dnd: QtObject {
            objectName: "dnd"
            property bool enabled: true
            property QtObject schedule: QtObject { objectName: "s"; property string from: "09:00" }
        }
        property var list: [1, 2]
    }
""" + fn + """
}""")
QTest.qWait(20)
dnd_before = h.eval(probe, "cfg.dnd")
h.eval(probe, '_restoreValue(cfg, "dnd", {"objectName": "dnd", "enabled": false, "schedule": {"objectName": "s", "from": "22:00"}})')
h.eval(probe, '_restoreValue(cfg, "list", [3])')
check(h.eval(probe, "cfg.dnd.enabled") is False and h.eval(probe, "cfg.dnd.schedule.from") == "22:00", "nested fields are restored")
check(h.eval(probe, "cfg.dnd") == dnd_before, "...in place (the JsonObject survives)")
check(h.eval(probe, "JSON.stringify(cfg.list)") == "[3]", "lists are replaced by a copy")
print("all settings simple-view checks passed")
