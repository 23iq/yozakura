"""Settings skeleton (S0) behaviour, offscreen.

* `advanced: true` entries render in a collapsed "Advanced" block
  (schema/Advanced.js); revealing one (a search jump) unfolds it.
* A section's reset button appears once it has changes and resets only
  that section.
* The sidebar tree: group ids resolve to their first page, the open group
  lists its pages.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("settings-advanced")
h = env.h

win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.services
import "../qs/modules/settings/schema/Advanced.js" as Advanced
Window {
    id: w
    width: 1100; height: 760; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function toggle(key, advanced) {
        return { "key": key, "type": "toggle", "label": "prefs.bar.compact", "advanced": advanced };
    }
    SettingsPage {
        objectName: "page"
        anchors.fill: parent
        category: Advanced.apply({
            "id": "demo", "icon": "gear", "title": "prefs.cat.bar",
            "sections": [
                { "id": "main", "title": "prefs.cat.bar", "entries": [w.toggle("bar.compact", false), w.toggle("bar.frameEnabled", true)] },
                { "id": "other", "title": "prefs.cat.dock", "entries": [w.toggle("bar.hoverToReveal", false)] }
            ]
        })
    }
}""")
page = h.find(win, "page")


def ev(expr: str, obj=None):
    return h.eval(obj or win, expr)


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)
    print("PASS", what)


QTest.qWait(200)
adv = 'findItem("settingsSection:advanced")'
check(ev(f"{adv} !== null"), "the page has an Advanced block")
check(ev(f"{adv}.expanded") is False, "the Advanced block starts collapsed")
check(ev('findItem("settingRow:bar.frameEnabled") !== null'), "the advanced entry renders inside it")
h.eval(page, 'reveal("advanced", "bar.frameEnabled")')
QTest.qWait(100)
check(ev(f"{adv}.expanded") is True, "revealing an advanced entry (a search jump) opens the block")

# Section reset: the Group's quiet action reads "Reset" while changed
main = 'findItem("settingsSection:main")'
check(ev(f"{main}.resetShown") is False, "no section reset without changes")
check(ev(f"{main}.actionText") == "", "…and no action on a plain section")
compact0, bg0 = ev("Config.bar.compact"), ev("Config.bar.hoverToReveal")
ev(f"SettingsStore.set('bar.compact', {str(not compact0).lower()})")
ev(f"SettingsStore.set('bar.hoverToReveal', {str(not bg0).lower()})")
QTest.qWait(50)
check(ev(f"{main}.resetShown") is True, "a changed section offers its reset")
check(ev(f"{main}.actionText") == ev('I18n.t("prefs.common.reset")'), "…as the Group action")
ev(f"{main}.actionTriggered()")
QTest.qWait(50)
check(ev("Config.bar.compact") == compact0, "section reset restores its entries")
check(ev("Config.bar.hoverToReveal") != bg0, "…and leaves other sections alone")
check(ev(f"{main}.resetShown") is False, "…and hides the action again")

# The Advanced block folds from its label action (Show / Hide)
ev(f"{adv}.expanded = false")
check(ev(f"{adv}.actionText") == ev('I18n.t("prefs.common.show")'), "a folded block offers Show")
ev(f"{adv}.actionTriggered()")
check(ev(f"{adv}.expanded") is True, "Show unfolds it")
check(ev(f"{adv}.actionText") == ev('I18n.t("prefs.common.hide")'), "…and then offers Hide")
ev(f"SettingsStore.set('bar.hoverToReveal', {str(bg0).lower()})")

# Sidebar tree in the real shell
shell_win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings
Window {
    width: 1100; height: 760; visible: true
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(shell_win, "shell")
h.eval(shell, 'select("island")')
QTest.qWait(200)
check(h.eval(shell, "currentCategory") == "notch", "a group id opens its first page")
h.eval(shell, 'select("overview")')
QTest.qWait(200)
check(h.eval(shell, "currentCategory") == "overview", "an old category id still opens its page")
h.eval(shell, 'navigate("look", "", "")')
QTest.qWait(200)
check(h.eval(shell, "currentCategory") == "appearance", "navigate accepts a group id")
print("all settings skeleton checks passed")
