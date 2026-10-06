"""Settings window (modules/settings) renderer behaviour, offscreen.

Loads the real SettingsShell (schema renderer, typed controls, editors) in a
private Xvfb with generated Config/Colors/I18n/GlobalStates (see
tests/lib/settings_env.py) and checks: every category page loads without
QML errors, typed rows write through SettingsStore and stage the matching
GlobalStates domain, modified/reset, visibleWhen, nested keys, the bar
layout editor, wallpaper folders, search navigation and the legacy tab map.
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


def settle(ms: int = 150) -> None:
    QTest.qWait(ms)


def row(entry_id: str):
    found = ev(f'w.findItem("settingRow:{entry_id}")')
    check(found is not None, f"row {entry_id} exists")
    return found


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


# Every category renders without QML errors.
order = ["appearance", "wallpapers", "surfaces", "bar", "bar-classic", "notch", "dock", "overview", "desktop",
         "lockscreen", "notifications", "windows", "input", "terminal", "system", "voice", "updates", "about"]
for cat in order:
    ev(f'select("{cat}")')
    settle(250)
    check(ev("currentCategory") == cat, f"select {cat}")
    page = h.find(win, "settingsPage").property("item")
    check(page is not None, f"{cat}: page loaded")
own_errors = [e for e in errors if "/widgets/" not in e]
check(not own_errors, "QML errors while loading pages:\n  " + "\n  ".join(own_errors))

# Toggle: writes Config, stages the shell domain, shows modified, resets.
ev('select("bar")')
settle(300)
r = row("bar.compact")
check(h.eval(r, "modified") is False, "compact starts at default")
ev("SettingsStore.set('bar.compact', true)")
check(ev("Config.bar.compact") is True, "toggle writes Config.bar.compact")
check(ev("GlobalStates.shellHasChanges") is True, "bar edit stages the shell snapshot")
check(h.eval(r, "modified") is True, "row shows modified")
check(ev("SettingsStore.hasChanges") is True, "changes bar visible")
ev("SettingsStore.reset({key: 'bar.compact'})")
check(ev("Config.bar.compact") is False and h.eval(r, "modified") is False, "reset restores default")

# visibleWhen
ev("SettingsStore.set('bar.frameEnabled', false)")
settle(50)
check(h.eval(row("bar.frameThickness"), "shown") is False, "frame thickness hidden without frame")
ev("SettingsStore.set('bar.frameEnabled', true)")
settle(50)
check(h.eval(row("bar.frameThickness"), "shown") is True, "frame thickness shown with frame")

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

# Real drag & drop with the mouse: first "left" chip onto the drawer zone.
editor = ev('w.findItem("settingRow:bar.layout.modules")')
ev("""(function() {
    var ed = null;
    (function find(item) {
        if (ed) return;
        if (item.zoneItems !== undefined) { ed = item; return; }
        for (var i = 0; i < item.children.length; i++) find(item.children[i]);
    })(w.findItem("settingRow:bar.layout.modules"));
    w.layoutEditor = ed;
})()""")
page = ev('w.findItem("settingsPage").item')
ev("w.findItem('settingsPage').item.contentY = 0")
ev("w.findItem('settingsPage').item.reveal('layout', '')")
settle(600)
moving = ev("w.layoutEditor.zoneItems()[0].chipItems()[1].moduleId")
start = ev("(function(){ var c = w.layoutEditor.zoneItems()[0].chipItems()[1]; return c.mapToItem(null, c.width / 2, c.height / 2); })()")
end = ev("(function(){ var z = w.layoutEditor.zoneItems()[2]; return z.mapToItem(null, z.width - 20, z.height - 16); })()")
from PySide6.QtCore import QPoint, Qt  # noqa: E402
p0 = QPoint(int(start.x()), int(start.y()))
p1 = QPoint(int(end.x()), int(end.y()))
QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, p0)
for i in range(1, 11):
    QTest.mouseMove(win, QPoint(p0.x() + (p1.x() - p0.x()) * i // 10, p0.y() + (p1.y() - p0.y()) * i // 10))
    settle(20)
check(ev("w.layoutEditor.dragging") is True, "drag started")
check(ev("w.layoutEditor.dropGroup") == "drawer", "hovering the drawer zone")
QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, p1)
settle(100)
drawer = json.loads(ev("JSON.stringify(Config.bar.layout.drawer)"))
check(drawer and drawer[-1] == moving, f"{moving} dropped at the end of the drawer: {drawer}")
check(moving not in json.loads(ev("JSON.stringify(Config.bar.layout.left)")), "dragged module left its group")

# Theme keys stage the theme snapshot
ev('select("appearance")')
settle(300)
ev("SettingsStore.set('theme.roundness', 4)")
check(ev("GlobalStates.themeHasChanges") is True, "theme edit stages the theme snapshot")
check(ev("Styling.radius(0)") == 4, "roundness applies live")
ev("SettingsStore.set('theme.lightMode', true)")
check(h.eval(row("theme.mode"), "modified") is True, "composite entry modified")
ev("SettingsStore.set('wallpaper.matugenScheme', 'scheme-rainbow')")
check(ev("GlobalStates.wallpaperManager.currentMatugenScheme") == "scheme-rainbow", "scheme goes to wallpapers.json")

# Apply / discard reach GlobalStates
ev("SettingsStore.apply()")
check(ev("GlobalStates.themeHasChanges") is False and ev("GlobalStates.shellHasChanges") is False, "apply")
check(ev("GlobalStates.applied") >= 2, "apply called for each domain")

# Wallpaper folders: extras staged, primary immediate
ev('select("wallpapers")')
settle(300)
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

# Lock screen gallery: a live preview (the real LockView) per registry style;
# picking a card writes lockscreen.style and stages the shell snapshot.
ev('select("lockscreen")')
settle(800)
lock_styles = ["glass", "paper", "terminal", "aurora", "neon", "poster"]
for sid in lock_styles:
    check(ev(f'w.findItem("lockPreview:{sid}") !== null'), f"gallery preview for {sid}")
check(ev('w.findItem("lockPreview:glass").children[0].preview === true'), "previews never grab focus or cava")
ev('w.findItem("lockPreview:paper").parent.parent.clicked()')
check(ev("Config.lockscreen.style") == "paper", "card click selects the style")
check(ev("GlobalStates.shellHasChanges") is True, "style change stages the shell snapshot")
check(h.eval(row("lockscreen.style"), "modified") is True, "style row shows modified")
ev("SettingsStore.reset({key: 'lockscreen.style'})")
check(ev("Config.lockscreen.style") == "glass", "reset restores glass")
check(h.eval(row("lockscreen.showVisualizer"), "shown") is True, "visualizer toggle shown")

# Search navigates to the entry and highlights it
search = h.find(win, "settingsSearch")
search.setProperty("text", "numerals")
settle(100)
results = h.find(win, "settingsSearchResults")
check(results.property("count") > 0, "search has results")
check(h.eval(results, "model[0].entryId") == "workspaces.numeralStyle", "best result is the numerals entry")
search.setProperty("text", "")
ev("navigate('bar', 'workspaces', 'workspaces.numeralStyle')")
settle(400)
check(ev("currentCategory") == "bar", "navigate switches category")
check(ev("SettingsStore.highlightedEntry") == "workspaces.numeralStyle", "entry highlighted")

# Legacy numeric tab (e.g. microphone activity opening the mixer)
ev("GlobalStates.settingsCurrentTab = 2")
settle(100)
check(ev("currentCategory") == "sound" and ev("GlobalStates.settingsCurrentTab") == 0, "legacy tab mapped")

# System: list editor (idle listeners), string list of paths (disks)
ev('select("system")')
settle(300)
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
check(ev("GlobalStates.shellHasChanges") is True, "system list edit stages the shell snapshot")
check(h.eval(lst, "modified") is True, "list row modified")
ev("SettingsStore.reset({key: 'system.idle.listeners'})")
check(ev("Config.system.idle.listeners.length") == n0, "list reset")
ev("SettingsStore.set('system.disks', ['/', '/home'])")
settle(50)
check(h.eval(row("system.disks"), "modified") is True, "disks list modified")
ev("SettingsStore.set('prefix.emoji', 'em')")
check(ev("Config.prefix.emoji") == "em" and "prefix" in json.loads(ev("JSON.stringify(Config.saved)")),
      "unstaged domain saved immediately")

# Notifications: screens multi-select, multiselect days, list rules, pattern
ev('select("notifications")')
settle(300)
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
check("notifications" in json.loads(ev("JSON.stringify(Config.saved)")), "notifications domain saved immediately")
ev("SettingsStore.set('notifications.presentation', 'notch')")
settle(50)
check(h.eval(row("notifications.position"), "shown") is False, "corner position hidden for notch toasts")
ev("SettingsStore.set('notifications.presentation', 'corner')")
settle(50)
check(h.eval(row("notifications.position"), "shown") is True, "corner position shown for corner toasts")
ev("SettingsStore.set('notifications.dnd.schedule.enabled', true)")
settle(50)
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
ev('select("terminal")')
settle(300)
tog = ev('w.findItem("appTheme:discord")')
check(tog is not None, "app theming row for discord")
h.eval(tog, "toggled(false)")
check(ev("Config.apps.theming.discord") is False, "app theming toggle writes apps.theming.discord")
check(h.eval(row("apps.theming"), "modified") is True, "app theming entry modified")
h.eval(ev('w.findItem("glassLink")'), "clicked()")
settle(400)
check(ev("currentCategory") == "appearance", "glass link opens Appearance")

# Windows page: color-role control, motion cards, nested pulse key, preview
ev('select("windows")')
settle(400)
FIND = """(function(name) {
    function find(item) {
        if (item[name] !== undefined) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = find(kids[i]); if (f) return f; }
        return null;
    }
    return find(this);
})"""
active = row("compositor.activeBorderColor")
h.eval(active, f"{FIND}.call(this, 'maxStops').commit(['primary', 'tertiary@0.5'])")
check(json.loads(ev("JSON.stringify(Config.compositor.activeBorderColor)")) == ["primary", "tertiary@0.5"],
      "color-role writes a gradient list")
check(ev("GlobalStates.compositorHasChanges") is True, "border edit stages the compositor snapshot")
check(h.eval(active, "modified") is True, "color-role row shows modified")
shadow = row("compositor.shadowColor")
h.eval(shadow, f"{FIND}.call(this, 'maxStops').commit(['primary@0.8'])")
check(ev("Config.compositor.shadowColor") == "primary@0.8", "single color-role writes a string")
ev("SettingsStore.set('compositor.borderPulse.enabled', true)")
settle(50)
check(h.eval(row("compositor.borderPulse.intensity"), "shown") is True, "pulse intensity shown when enabled")
check(ev("Config.compositor.borderPulse.source") == "cava", "nested pulse write keeps siblings")
card = ev('w.findItem("motionCard:springs")')
check(card is not None, "motion profile cards rendered")
h.eval(card, "clicked()")
check(ev("Config.compositor.motionProfile") == "springs", "motion card selects the profile")
ev("SettingsStore.set('compositor.motionProfile', 'off')")
settle(50)
check(h.eval(row("compositor.motionDurationScale"), "shown") is False, "speed hidden for the off profile")
ev("SettingsStore.set('compositor.gapsIn', 7)")
settle(50)
readout = ev('w.findItem("windowsReadout")')
check(readout is not None and "7" in readout.property("text"), "preview readout follows the gaps")
# Leave the page before the engine is torn down: PySide destroys the Config/
# Colors singletons first and the live preview bindings would read them dead.
ev('select("about")')
settle(300)
legal = ev('w.findItem("aboutLegalNotice")')
check(legal is not None, "about page shows the legal row")
h.eval(legal, "expanded = true")
settle(300)
notice = ev('w.findItem("aboutNoticeText")')
check(notice is not None and h.eval(notice, "visible") and h.eval(legal, "noticePath").endswith("/NOTICE"),
      "legal row expands to the NOTICE viewer")

# Island activities editor: every registry entry, reorder / side / enable
# write notch.activities as [{id, side, enabled}]
ev('select("notch")')
settle(250)
editor = ev('w.findItem("islandActivitiesEditor")')
check(editor is not None, "island activities editor rendered")
ids = json.loads(h.eval(editor, "JSON.stringify(list.map(e => e.id))"))
check(len(ids) == 8 and ids[0] == "media", f"island activities in registry order ({ids})")
h.eval(editor, "write(Registry.move(list, 0, 2))")
settle(50)
stored = json.loads(ev("JSON.stringify(Config.notch.activities)"))
check([e["id"] for e in stored][:3] == [ids[1], ids[2], "media"], f"drag reorder stored ({stored[:3]})")
h.eval(editor, "write(Registry.setField(list, 'battery', 'enabled', false))")
h.eval(editor, "write(Registry.setField(list, 'osd', 'side', 'leading'))")
settle(50)
stored = {e["id"]: e for e in json.loads(ev("JSON.stringify(Config.notch.activities)"))}
check(stored["battery"]["enabled"] is False and stored["osd"]["side"] == "leading", "enable and side stored")

late = [e for e in errors if "/widgets/" not in e]
check(not late, "QML errors during interaction:\n  " + "\n  ".join(late))
print("settings-ui: ok")
