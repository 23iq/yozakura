"""Settings window (modules/settings) renderer behaviour, offscreen.

Loads the real SettingsShell (schema renderer, typed controls, editors) in a
private Xvfb with generated Config/Colors/I18n/GlobalStates (see
tests/lib/settings_env.py) and checks: every category page loads without
QML errors, typed rows write through SettingsStore live (nothing staged,
nothing to apply), modified/reset, visibleWhen, nested keys, the bar
layout editor, wallpaper folders, search navigation and page requests from
the shell (settingsCategory). The new window behaviour (undo, tabs, stages,
keep-alive) is in tests/settings-shell.test.py.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402
from waits import settle, wait_until  # noqa: E402

env = SettingsEnv("settings-ui", wallpaper={
    "dir": "/walls", "scanDirs": ["/walls"], "paths": ["/walls/a.jpg", "/walls/b.png"], "current": "/walls/a.jpg"})
h = env.h

errors: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "Unable to assign",
                              "failed to load", "Error:")):
        errors.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


qInstallMessageHandler(_capture)

win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.globals
import qs.modules.theme
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1100; height: 760; visible: true
    // Repeater delegates have no QObject parent: search the visual tree.
    property var layoutEditor: null
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr: str, obj=None):
    return h.eval(obj or shell, expr)


def until(pred, what: str) -> None:
    check(wait_until(pred), what)


def select(cat: str) -> None:
    """Open a page and wait for its asynchronous build."""
    ev(f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")


def row(entry_id: str):
    found = ev(f'w.findItem("settingRow:{entry_id}")')
    if found is None:
        # a fitted page builds its More sheet on first open
        ev('(function () { var p = w.findItem("settingsPage").item; if (p && p.moreBuilt !== undefined) p.moreBuilt = true; })()')
        QTest.qWait(50)
        found = ev(f'w.findItem("settingRow:{entry_id}")')
    check(found is not None, f"row {entry_id} exists")
    return found


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


# Every category renders without QML errors.
order = ["appearance", "wallpapers", "bar", "notch", "dock", "overview", "desktop", "dashboard", "osd", "menus",
         "lockscreen", "notifications", "windows", "input", "terminal", "system", "voice", "updates", "about"]
for cat in order:
    select(cat)
    check(ev("currentCategory") == cat, f"select {cat}")
    page = h.find(win, "settingsPage").property("item")
    check(page is not None, f"{cat}: page loaded")
own_errors = [e for e in errors if "/widgets/" not in e]
check(not own_errors, "QML errors while loading pages:\n  " + "\n  ".join(own_errors))

# Toggle: writes Config live (no staging), shows modified, resets.
select("bar")
r = row("bar.compact")
check(h.eval(r, "modified") is False, "compact starts at default")
ev("SettingsStore.set('bar.compact', true)")
check(ev("Config.bar.compact") is True, "toggle writes Config.bar.compact")
check(ev("GlobalStates.shellHasChanges") is False and ev("SettingsStore.hasChanges") is False,
      "a window edit is live: nothing staged")
check(h.eval(r, "modified") is True, "row shows modified")
ev("SettingsStore.reset({key: 'bar.compact', label: 'prefs.bar.compact'})")
check(ev("Config.bar.compact") is False and h.eval(r, "modified") is False, "reset restores default")

# visibleWhen
ev("SettingsStore.set('bar.frameEnabled', false)")
settle()
check(h.eval(row("bar.containBar"), "shown") is False, "inside-the-frame hidden without frame")
ev("SettingsStore.set('bar.frameEnabled', true)")
settle()
check(h.eval(row("bar.containBar"), "shown") is True, "inside-the-frame shown with frame")
check(ev('w.findItem("settingRow:bar.frameThickness")') is None, "an out-of-window entry has no row")

# Host/style pickers note where they show while the notch is off
select("menus")
pm = row("layout.powermenu.style")
check(h.eval(pm, "shownAs") == "", "no note while the notch is on")
ev("SettingsStore.set('notch.enabled', false)")
settle()
shown_as = h.eval(pm, "shownAs")
check(shown_as != "" and shown_as != "fullscreen", f"auto power menu notes its fallback label ({shown_as!r})")
ev("SettingsStore.set('layout.powermenu.style', 'radial')")
settle()
check(h.eval(pm, "shownAs") == "", "an explicit off-notch style has no note")
ev("SettingsStore.reset({key: 'layout.powermenu.style'})")
ev("SettingsStore.reset({key: 'notch.enabled'})")
settle()
check(h.eval(pm, "shownAs") == "", "note gone with the notch back on")

# Compositor gate note: silent on Hyprland, counts gated entries on niri
select("windows")
note = ev('w.findItem("compositorOnlyNote", w.findItem("settingsPage").item)')
check(note is not None and h.eval(note, "visible") is False, "no compositor note on Hyprland")
h.eval(note, "YozdService.compositorName = 'niri'")
until(lambda: h.eval(ev('w.findItem("compositorOnlyNote", w.findItem("settingsPage").item)'), "visible") is True, "compositor note shows on niri")
note = ev('w.findItem("compositorOnlyNote", w.findItem("settingsPage").item)')
check("Hyprland" in h.eval(note, "text"), "compositor note names the supporting compositors")
h.eval(note, "YozdService.compositorName = 'hyprland'")
settle()
select("bar")

# Nested key keeps the rest of the object
ev("SettingsStore.set('bar.layout.style', 'islands')")
check(ev("Config.bar.layout.style") == "islands", "nested write")
check(ev("Config.bar.layout.left.length") == 4, "nested write keeps siblings")

# Bar layout editor
layout_row = row("bar.layout.modules")
moved = h.eval(layout_row, """(function() {
    function find(item) {
        if (item.moveTo !== undefined && item.display !== undefined) return item;
        for (var i = 0; i < item.children.length; i++) { var f = find(item.children[i]); if (f) return f; }
        return null;
    }
    var ed = find(this);
    ed.moveTo('clock', 'left', 0);
    return true;
}).call(this)""")
check(moved is True, "layout editor found")
check(ev("Config.bar.layout.left[0]") == "clock", "drag/keyboard move lands in left")
check("clock" not in json.loads(ev("JSON.stringify(Config.bar.layout.right)")), "module removed from its old group")
check(h.eval(layout_row, "modified") is True, "layout row modified")

# Real drag & drop with the mouse in the card's compact editor (one group at
# a time): the second "left" chip dragged before the first reorders the group.
ev("""(function() {
    var ed = null;
    (function find(item) {
        if (ed) return;
        if (item.zoneItems !== undefined) { ed = item; return; }
        for (var i = 0; i < item.children.length; i++) find(item.children[i]);
    })(w.findItem("settingRow:bar.layout.modules"));
    w.layoutEditor = ed;
})()""")
check(ev("w.layoutEditor.compact") is True, "the card's modules editor is compact")
check(ev("w.layoutEditor.activeGroup") == "left", "it shows the first group")
settle(10)
moving = ev("w.layoutEditor.zoneItems()[0].chipItems()[1].moduleId")
start = ev("(function(){ var c = w.layoutEditor.zoneItems()[0].chipItems()[1]; return c.mapToItem(null, c.width / 2, c.height / 2); })()")
end = ev("(function(){ var c = w.layoutEditor.zoneItems()[0].chipItems()[0]; return c.mapToItem(null, 4, c.height / 2); })()")
from PySide6.QtCore import QPoint, Qt  # noqa: E402
p0 = QPoint(int(start.x()), int(start.y()))
p1 = QPoint(int(end.x()), int(end.y()))
QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, p0)
for i in range(1, 11):
    QTest.mouseMove(win, QPoint(p0.x() + (p1.x() - p0.x()) * i // 10, p0.y() + (p1.y() - p0.y()) * i // 10))
    settle(1)
check(ev("w.layoutEditor.dragging") is True, "drag started")
check(ev("w.layoutEditor.dropGroup") == "left", "hovering the left group")
QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, p1)
until(lambda: not ev("w.layoutEditor.dragging"), "drop finished")
left = json.loads(ev("JSON.stringify(Config.bar.layout.left)"))
check(left and left[0] == moving, f"{moving} dragged to the front of the group: {left}")
# the other groups: picked in the card's segmented; Add opens the unused modules
ev("w.layoutEditor.shownGroup = 'right'")
settle(5)
check(ev("w.layoutEditor.zoneItems()[1].visible") is True and ev("w.layoutEditor.zoneItems()[0].visible") is False, "one group at a time")
ev("w.layoutEditor.adding = true")
settle(5)
check(ev("w.layoutEditor.zoneItems()[3].visible") is True, "Add shows the modules not on the bar")
ev("w.layoutEditor.adding = false; w.layoutEditor.shownGroup = ''")

# Theme keys apply live
select("appearance")
ev("SettingsStore.set('theme.roundness', 4)")
check(ev("GlobalStates.themeHasChanges") is False and ev("Config.theme.roundness") == 4, "theme edit applies live")
check(ev("Styling.radius(0)") == 4, "roundness applies live")
ev("SettingsStore.set('theme.lightMode', true)")
check(h.eval(row("theme.mode"), "modified") is True, "composite entry modified")
ev("SettingsStore.set('wallpaper.matugenScheme', 'scheme-rainbow')")
check(ev("GlobalStates.wallpaperManager.currentMatugenScheme") == "scheme-rainbow", "scheme goes to wallpapers.json")

# Wallpaper folders: extras staged, primary immediate
select("wallpapers")
folders = row("desktop.wallpaperFolders")
h.eval(folders, """(function() {
    function find(item) {
        if (item.applyFolder !== undefined) return item;
        for (var i = 0; i < item.children.length; i++) { var f = find(item.children[i]); if (f) return f; }
        return null;
    }
    var ed = find(this);
    ed.applyFolder('/extra/walls/', 'add');
    ed.applyFolder('/extra/walls', 'add');
    ed.applyFolder('/extra/walls', 'primary');
}).call(this)""")
check(ev("GlobalStates.wallpaperManager.wallpaperDir") == "/extra/walls", "primary folder set immediately")
check(json.loads(ev("JSON.stringify(Config.desktop.wallpaperFolders)")) == ["/walls"],
      "old primary kept as extra, no duplicates")

# Lock screen gallery: a picture (the real LockView, captured) per registry
# style; picking a card writes lockscreen.style live.
select("lockscreen")
lock_styles = ["glass", "paper", "terminal", "aurora", "neon", "poster"]
for sid in lock_styles:
    until(lambda: ev(f'w.findItem("lockPreview:{sid}") !== null'), f"gallery preview for {sid}")  # noqa: B023
until(lambda: ev('w.findItem("lockPreview:glass").grabbed !== null'), "every style is pictured, one after the other")
check(ev('w.findItem("lockPreview:glass").children[1].children[0].active') is False, "no live lock view stays after its picture")
ev('w.findItem("lockPreview:paper").parent.parent.parent.clicked()')
check(ev("Config.lockscreen.style") == "paper", "card click selects the style")
check(ev("GlobalStates.shellHasChanges") is False, "style change applies live")
check(h.eval(row("lockscreen.style"), "modified") is True, "style row shows modified")
ev("SettingsStore.reset({key: 'lockscreen.style'})")
check(ev("Config.lockscreen.style") == "glass", "reset restores glass")
check(h.eval(row("lockscreen.showVisualizer"), "shown") is True, "visualizer toggle shown")

# Search navigates to the entry and highlights it
search = h.find(win, "settingsSearch")
search.setProperty("text", "numerals")
results = h.find(win, "settingsSearchResults")
until(lambda: results.property("count") > 0, "search has results")
check(h.eval(results, "model[0].entryId") == "workspaces.numeralStyle", "best result is the numerals entry")
search.setProperty("text", "")
ev("navigate('bar', 'workspaces', 'workspaces.numeralStyle')")
until(lambda: ev("currentCategory") == "bar", "navigate switches category")
until(lambda: ev("SettingsStore.highlightedEntry") == "workspaces.numeralStyle", "entry highlighted")

# Another part of the shell asks for a page (microphone activity -> Sound)
ev("GlobalStates.settingsCategory = 'sound'")
until(lambda: ev("currentCategory") == "sound", "settingsCategory opens the page")

# Power / System: list editor (idle listeners), string list of paths (disks)
select("power")
n0 = ev("Config.system.idle.listeners.length")
lst = row("system.idle.listeners")
h.eval(lst, """(function() {
    function find(item) {
        if (item.objectName === "listAdd") return item;
        for (var i = 0; i < item.children.length; i++) { var f = find(item.children[i]); if (f) return f; }
        return null;
    }
    find(this).clicked();
}).call(this)""")
check(ev("Config.system.idle.listeners.length") == n0 + 1, "list editor adds an item")
check(ev(f"Config.system.idle.listeners[{n0}].timeout") == 60, "new listener uses newItem")
check(ev("GlobalStates.shellHasChanges") is False, "system list edit applies live")
check(h.eval(lst, "modified") is True, "list row modified")
ev("SettingsStore.reset({key: 'system.idle.listeners'})")
check(ev("Config.system.idle.listeners.length") == n0, "list reset")
select("system")
check(ev('w.findItem("settingRow:system.disks")') is None, "mount points are not a window row (yozakura config)")
ev("Config.saved = []")
ev("SettingsStore.set('prefix.emoji', 'em2')")
check(ev("Config.prefix.emoji") == "em2" and ev("Config.saved.length") == 0,
      "a live edit is left to the domain's own auto-save (one writer)")

# Notifications: screens multi-select, multiselect days, list rules, pattern
select("notifications")
scr = row("notifications.screens")
chips = h.eval(scr, """(function() {
    var out = [];
    (function walk(item) {
        if (item.allLabel !== undefined && item.screens !== undefined)
            item.screens = [{ name: "DP-1", width: 2560, height: 1440 }, { name: "HDMI-A-1", width: 1920, height: 1080 }];
        if (item.toggle !== undefined && item.allSelected !== undefined) out.push(item);
        for (var i = 0; i < item.children.length; i++) walk(item.children[i]);
    })(this);
    var c = out[0];
    c.toggle("HDMI-A-1");
    return c.options.length;
}).call(this)""")
check(chips == 2, f"screens control lists the connected monitors ({chips})")
check(json.loads(ev("JSON.stringify(Config.notifications.screens)")) == ["HDMI-A-1"], "screen selected")
check("notifications" not in json.loads(ev("JSON.stringify(Config.saved)")), "notifications domain is left to its own auto-save (one writer)")
ev("SettingsStore.set('notifications.presentation', 'notch')")
settle()
check(h.eval(row("notifications.position"), "shown") is False, "corner position hidden for notch toasts")
ev("SettingsStore.set('notifications.presentation', 'corner')")
settle()
check(h.eval(row("notifications.position"), "shown") is True, "corner position shown for corner toasts")
# A long option set (7 corners) is an inline kit Dropdown; up to four are a Segmented
pos = row("notifications.position")
check(h.eval(pos, "stacked") is False, "a long selector stays inline")
picked = h.eval(pos, """(function() {
    var found = null;
    (function walk(item) {
        if (!found && item.segmentLimit !== undefined) found = item;
        for (var i = 0; i < item.children.length; i++) walk(item.children[i]);
    })(this);
    return found.dropdown;
}).call(this)""")
check(picked is True, "…drawn as a Dropdown")
ev("SettingsStore.set('notifications.dnd.schedule.enabled', true)")
settle()
days = row("notifications.dnd.schedule.days")
check(h.eval(days, "shown") is True, "schedule days shown")
ev("SettingsStore.set('notifications.dnd.schedule.days', [1, 2, 3, 4, 5])")
check(h.eval(days, "modified") is True, "weekday selection modified")
ev("SettingsStore.set('notifications.rules', [{app: 'discord', action: 'mute'}])")
check(ev("Config.notifications.rules[0].action") == "mute", "rules list written")
frm = row("notifications.dnd.schedule.from")
h.eval(frm, """(function() {
    (function walk(item) {
        if (item.edited !== undefined && item.invalid !== undefined) { item.edited("25:99"); item.edited("23:30"); return; }
        for (var i = 0; i < item.children.length; i++) walk(item.children[i]);
    })(this);
}).call(this)""")
check(ev("Config.notifications.dnd.schedule.from") == "23:30", "time pattern rejects 25:99, accepts 23:30")
test_btn = ev('w.findItem("testNotification")')
check(test_btn is not None, "test notification button")
h.eval(test_btn, "clicked()")
check(h.eval(row("notifications.status"), "Notifications.sent.length") == 1, "test notification sent")

# Terminal & Apps: per-app theming toggles + glass link
select("terminal")
# a side switch waiting on another: dimmed, no sentence; a press turns that one on
ev("SettingsStore.set('terminal.enabled', false)")
QTest.qWait(50)
blink = ev('w.findItem("settingRow:terminal.cursorBlink", w.findItem("heroRight", w.findItem("settingsPage").item))')
check(blink is not None and h.eval(blink, "dimmed") is True and h.eval(blink, "caption") == "", "the waiting side switch is dimmed, no note")
h.eval(blink, "wake()")
check(ev("Config.terminal.enabled") is True, "...and a press turns the prompt on first")
# the app theming card is in the More sheet, built on first open
ev('w.findItem("settingsPage").item.moreBuilt = true')
QTest.qWait(100)
tog = ev('w.findItem("appTheme:discord")')
check(tog is not None, "app theming row for discord")
h.eval(tog, "toggled(false)")
check(ev("Config.apps.theming.discord") is False, "app theming toggle writes apps.theming.discord")
check(h.eval(row("apps.theming"), "modified") is True, "app theming entry modified")
h.eval(ev('w.findItem("glassLink")'), "clicked()")
until(lambda: ev("currentCategory") == "appearance", "glass link opens Appearance")

# Windows page: color-role control, nested pulse key, preview
select("windows")
FIND = """(function(name) {
    function find(item) {
        if (item[name] !== undefined) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = find(kids[i]); if (f) return f; }
        return null;
    }
    return find(this);
})"""
active = row("compositor.inactiveBorderColor")
h.eval(active, f"{FIND}.call(this, 'maxStops').commit(['primary', 'tertiary@0.5'])")
check(json.loads(ev("JSON.stringify(Config.compositor.inactiveBorderColor)")) == ["primary", "tertiary@0.5"],
      "color-role writes a gradient list")
check(ev("GlobalStates.compositorHasChanges") is False, "border edit applies live")
check(h.eval(active, "modified") is True, "color-role row shows modified")
ev("SettingsStore.set('compositor.borderPulse.enabled', true)")
settle()
check(ev("Config.compositor.borderPulse.source") == "cava", "nested pulse write keeps siblings")
ev("SettingsStore.set('compositor.gapsIn', 7)")
settle()
readout = ev('w.findItem("windowsReadout")')
check(readout is not None and "7" in readout.property("text"), "preview readout follows the gaps")
check(ev('w.findItem("motionCard:springs")') is None, "motion lives on Look, not Windows")

# Look: motion is the one Motion macro (the profile cards are not a row)
select("appearance")
check(ev('w.findItem("macro:motion")') is not None, "the Motion macro is on Look")
check(ev('w.findItem("motionCard:springs")') is None, "no second motion control")
# Leave the page before the engine is torn down: PySide destroys the Config/
# Colors singletons first and the live preview bindings would read them dead.
select("about")
legal = ev('w.findItem("aboutLegalNotice")')
check(legal is not None, "about page shows the legal row")
h.eval(legal, "expanded = true")
until(lambda: ev('w.findItem("aboutNoticeText") !== null'), "NOTICE viewer created")
settle()
notice = ev('w.findItem("aboutNoticeText")')
check(notice is not None and h.eval(notice, "visible") and h.eval(legal, "noticePath").endswith("/NOTICE"),
      "legal row expands to the NOTICE viewer")

# Island activities editor: every registry entry, reorder / side / enable
# write notch.activities as [{id, side, enabled}]
select("notch")
editor = ev('w.findItem("islandActivitiesEditor")')
check(editor is not None, "island activities editor rendered")
ids = json.loads(h.eval(editor, "JSON.stringify(list.map(e => e.id))"))
check(len(ids) == 8 and ids[0] == "media", f"island activities in registry order ({ids})")
h.eval(editor, "write(Registry.move(list, 0, 2))")
settle()
stored = json.loads(ev("JSON.stringify(Config.notch.activities)"))
check([e["id"] for e in stored][:3] == [ids[1], ids[2], "media"], f"drag reorder stored ({stored[:3]})")
h.eval(editor, "write(Registry.setField(list, 'battery', 'enabled', false))")
h.eval(editor, "write(Registry.setField(list, 'osd', 'side', 'leading'))")
settle()
stored = {e["id"]: e for e in json.loads(ev("JSON.stringify(Config.notch.activities)"))}
check(stored["battery"]["enabled"] is False and stored["osd"]["side"] == "leading", "enable and side stored")

# Closing never asks: every change is already applied and saved.
ev("GlobalStates.settingsWindowVisible = false")
settle()
check(ev("GlobalStates.settingsWindowVisible") is False, "a close closes at once")
ev("GlobalStates.settingsWindowVisible = true")

late = [e for e in errors if "/widgets/" not in e]
check(not late, "QML errors during interaction:\n  " + "\n  ".join(late))
print("settings-ui: ok")
# no interpreter teardown: kept-alive pages would outlive the singletons
h.exit(0)
