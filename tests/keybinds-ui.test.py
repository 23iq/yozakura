"""Keybinds UI, offscreen: keycap rendering, the settings editor (enable,
record incl. Super, chips, mouse, conflicts kept + filter, the add dialog
(keys, action search, app picker, group by action, Esc/Cancel), remove,
reset, Advanced, search + empty state) and the cheatsheet panel (search,
edit, Esc). Real modules/components,
modules/keybinds and modules/settings files on tests/lib/settings_env.py.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QEvent, QPointF, Qt, qInstallMessageHandler  # noqa: E402
from PySide6.QtGui import QGuiApplication, QKeyEvent, QMouseEvent  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import APP_ID, SettingsEnv, default_binds  # noqa: E402

binds = default_binds()
binds["custom"] = [
    {"name": "Terminal", "keys": [{"modifiers": ["SUPER"], "key": "Return"}],
     "actions": [{"id": "command.run", "args": {"command": "kitty"}, "layouts": []}], "enabled": True},
    {"name": "", "keys": [{"modifiers": ["SUPER"], "key": "1"}],
     "actions": [{"id": "workspace.switch", "args": {"index": "1"}, "layouts": []}], "enabled": True},
]
env = SettingsEnv("keybinds-ui", binds=binds)
h = env.h

errors: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "Unable to assign",
                              "failed to load", "Error:", "Cannot open")):
        errors.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


qInstallMessageHandler(_capture)

win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.components
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1200; height: 860; visible: true
    property int closes: 0
    property var edits: []
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function findAll(test, from, out) {
        out = out || [];
        var item = from || w.contentItem;
        if (test(item)) out.push(item);
        for (var i = 0; i < item.children.length; i++) findAll(test, item.children[i], out);
        return out;
    }
    Column {
        objectName: "combos"
        KeyCombo { objectName: "superShiftS"; modifiers: ["SHIFT", "SUPER"]; key: "S" }
        KeyCombo { objectName: "arrow"; modifiers: []; key: "Up" }
        KeyCombo { objectName: "big"; modifiers: []; key: "Up"; sizeOffset: 6 }
        KeyCombo { objectName: "lone"; modifiers: ["SUPER"]; key: "Super_L" }
        KeyCombo { objectName: "empty"; key: ""; placeholder: "Not set" }
    }
    SettingsShell { objectName: "shell"; visible: false; width: 1180; height: 840 }
    CheatsheetPanel {
        objectName: "cheatsheet"
        visible: false
        width: 1200; height: 840
        onCloseRequested: w.closes++
        onEditRequested: uid => w.edits = w.edits.concat([uid])
    }
}""")
shell = h.find(win, "shell")


def ev(expr: str, obj=None):
    return h.eval(obj or shell, expr)


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def find(name: str):
    return ev(f'w.findItem("{name}")')


def caps_of(name: str) -> list:
    return json.loads(ev(f'JSON.stringify(w.findAll(i => i.cap !== undefined && i.capHeight !== undefined, '
                         f'w.findItem("{name}")).map(i => i.kind + ":" + (i.cap.text || i.cap.icon)))'))


# --- Keycaps -------------------------------------------------------------------
QTest.qWait(200)
check(caps_of("superShiftS") == ["super:", "text:Shift", "text:S"], f"Super+Shift+S caps: {caps_of('superShiftS')}")
check(caps_of("arrow") == ["icon:arrowUp"], "arrow key is a glyph")
check(caps_of("lone") == ["super:"], "a lone Super bind shows one Super cap")
check(caps_of("empty") == [], "empty combo has no caps")
glyph = json.loads(ev('JSON.stringify(w.findAll(i => i.source !== undefined && String(i.source).indexOf("super-key.svg") '
                     '!== -1, w.findItem("superShiftS")).map(i => i.visible && i.status === 1))'))
check(glyph == [True], f"Super cap shows the loaded super-key.svg glyph ({glyph})")
small = ev('w.findItem("arrow").implicitHeight')
big = ev('w.findItem("big").implicitHeight')
check(big > small, f"keycap size follows the font size ({small} -> {big})")
check(ev('w.findAll(i => i.cap !== undefined && i.capHeight !== undefined, w.findItem("arrow"))[0].children[1]'
         '.children[0].children[1].text') == ev("Icons.arrowUp", win), "arrow cap draws Icons.arrowUp")

# --- Settings editor -----------------------------------------------------------
ev("visible = true")
ev('select("input")')
QTest.qWait(600)
check(not [e for e in errors if "/widgets/" not in e], "QML errors:\n  " + "\n  ".join(errors))
check(find("keybindRow:core:system.tools") is not None, "core bind row rendered")
check(find("keybindRow:custom:0") is not None, "custom bind row rendered")
adapter = "KeybindsStore.adapter"

# the list is compact: no switch per row, it lives in the opened editor
check(ev('w.findItem("keybindEnabled", w.findItem("keybindRow:core:system.tools"))') is None, "no switch in the list")
check(ev('w.findItem("keybindRow:core:system.tools").implicitHeight') <= 44, "rows are one compact line")

# enable switch (core binds go to the adapter's `disabled` list)
ev('KeybindsStore.expandedUid = "core:system.tools"')
QTest.qWait(300)
toggle = ev('w.findItem("keybindEnabled", w.findItem("keybindRow:core:system.tools"))')
check(toggle is not None, "the opened editor has the enable switch")
h.eval(toggle, "flip()")
check(ev(f"{adapter}.disabled.indexOf('system.tools') !== -1"), "disabling a core bind lists it in `disabled`")
check(ev("CompositorTomlWriter.writes") > 0, "an edit regenerates the compositor TOML")
check(ev("KeybindsStore.row('core:system.tools').enabled") is False, "row shows disabled")
QTest.qWait(50)
toggle = ev('w.findItem("keybindEnabled", w.findItem("keybindRow:core:system.tools"))')
check(h.eval(toggle, "checked") is False, "switch follows the bind")
h.eval(toggle, "flip()")
check(ev(f"{adapter}.disabled.length") == 0, "re-enabling removes it")

# record: held modifiers + key
ev('KeybindsStore.expandedUid = "core:system.tools"')
QTest.qWait(400)
check(find("keyCapture") is not None, "details show the recorder")


def recorder_start():
    """(pad, recorder) of the expanded row's first combo, in record mode."""
    QTest.qWait(30)
    p = find("keyCapture")
    r = h.eval(p, "parent")
    h.eval(r, "start()")
    check(h.eval(r, "recording") is True, "record mode on")
    return p, r



def key(item, k, mods=Qt.NoModifier, text="", release=False):
    t = QEvent.KeyRelease if release else QEvent.KeyPress
    QGuiApplication.sendEvent(item, QKeyEvent(t, k, mods, text))


pad, recorder = recorder_start()
key(pad, Qt.Key_Super_L, Qt.MetaModifier)
check(h.eval(recorder, "draftMods.join()") == "SUPER", "held Super lights its chip")
key(pad, Qt.Key_K, Qt.MetaModifier | Qt.ShiftModifier, "K")
QTest.qWait(50)
tools = f"{adapter}.{APP_ID}.system.tools"
check(ev(f"JSON.stringify([{tools}.modifiers, {tools}.key])") == '[["SUPER","SHIFT"],"K"]',
      f"recorded Super+Shift+K: {ev(f'JSON.stringify([{tools}.modifiers, {tools}.key])')}")
QTest.qWait(30)
check(h.eval(find("keyCapture"), "parent.recording") is False, "record mode ends on capture")

# chips: the compositor grabs Super combos, so toggle it and press the key
pad, recorder = recorder_start()
h.eval(recorder, "toggleMod('SUPER', true)")
key(pad, Qt.Key_F5, Qt.NoModifier)
check(ev(f"JSON.stringify([{tools}.modifiers, {tools}.key])") == '[["SUPER"],"F5"]', "chip Super + F5")

# shifted symbols record the unshifted key
pad, recorder = recorder_start()
key(pad, Qt.Key_Question, Qt.MetaModifier | Qt.ShiftModifier, "?")
check(ev(f"{tools}.key") == "SLASH", "Shift+/ records SLASH")

# a lone Super press binds Super itself
pad, recorder = recorder_start()
key(pad, Qt.Key_Super_L, Qt.MetaModifier)
key(pad, Qt.Key_Super_L, Qt.NoModifier, release=True)
check(ev(f"JSON.stringify([{tools}.modifiers, {tools}.key])") == '[["SUPER"],"Super_L"]', "lone Super")

# mouse buttons need a modifier
pad, recorder = recorder_start()
mouse_area = h.eval(pad, "children[1]")
pos = QPointF(10, 10)
QGuiApplication.sendEvent(mouse_area, QMouseEvent(QEvent.MouseButtonPress, pos, pos, Qt.RightButton, Qt.RightButton,
                                                  Qt.AltModifier))
check(ev(f"JSON.stringify([{tools}.modifiers, {tools}.key])") == '[["ALT"],"mouse:273"]', "Alt + right click")

# Esc alone cancels
pad, recorder = recorder_start()
key(pad, Qt.Key_Escape)
check(h.eval(recorder, "recording") is False and ev(f"{tools}.key") == "mouse:273", "Esc cancels recording")

# modified + reset
check(ev("KeybindsStore.isModified(KeybindsStore.row('core:system.tools'))") is True, "changed core bind is modified")
ev('KeybindsStore.reset("core:system.tools")')
check(ev(f"JSON.stringify([{tools}.modifiers, {tools}.key])") == '[["SUPER"],"S"]', "reset restores the default")

# conflicts: another bind and a compositor bind. Saving a taken combo is
# allowed and keeps both binds as they are (nothing is overwritten).
ev('KeybindsStore.expandedUid = "custom:0"')
QTest.qWait(200)
ev('KeybindsStore.setKeys("custom:0", [{modifiers: ["SUPER"], key: "s"}])')
check(ev(f"JSON.stringify([{adapter}.custom[0].keys[0].key, {tools}.key])") == '["s","S"]',
      "a conflicting combo is saved and the other bind keeps its own")
check(ev(f"{adapter}.custom.length") == 2 and ev(f"{adapter}.disabled.length") == 0, "no bind removed or disabled")
check(ev("KeybindsStore.conflictsOf('custom:0').map(c => c.uid).join()") == "core:system.tools",
      "duplicate combo is a conflict")
check(ev("KeybindsStore.conflictsOf('core:system.tools').length") == 1, "both sides are marked")
QTest.qWait(100)
check(h.eval(find("keybindRow:core:system.tools"), "conflicted") is True, "row highlights the conflict")
note = ev('w.findItem("conflictNote", w.findItem("keybindRow:core:system.tools"))')
check(h.eval(note, "visible") is True and "Terminal" in h.eval(note, "text"), "the row names the other bind")
clash = ev('w.findItem("clashNote", w.findItem("keybindRow:custom:0"))')
check(h.eval(clash, "visible") is True and "kept" in h.eval(clash, "text"),
      f"the editor warns and says both are kept ({h.eval(clash, 'text')})")
# while recording, a typed key name is checked live
pad = find("keyCapture")
rec = h.eval(pad, "parent")
h.eval(rec, "start(); toggleMod('SUPER', true)")
h.eval(ev('w.findItem("keyName", w.findItem("keybindRow:custom:0"))'), "text = 'S'")
check("Take a screenshot" not in (h.eval(rec, "draftClashText") or "")
      and "Open tools" in (h.eval(rec, "draftClashText") or ""), f"live clash: {h.eval(rec, 'draftClashText')}")
h.eval(rec, "cancel()")
# the toolbar chip lists only the conflicting binds
ev("KeybindsStore.conflictFilter = true")
QTest.qWait(100)
check(find("keybindRow:core:system.tools") is not None and find("keybindRow:core:launcher") is None,
      "conflict filter shows only conflicts")
chip = find("keybindsConflicts")
h.eval(chip, "children[1].clicked(null)")
check(ev("KeybindsStore.conflictFilter") is False, "clicking the chip shows everything again")
ev('KeybindsStore.hyprBinds = [{modmask: 64, key: "1", has_description: true, description: "Discord", submap: ""}]')
check(ev("KeybindsStore.conflictText('custom:1')") == "Compositor: Discord", "native compositor bind conflict")
ev("KeybindsStore.hyprBinds = []")
ev('KeybindsStore.setKeys("custom:0", [{modifiers: ["SUPER"], key: "Return"}])')
check(ev("KeybindsStore.conflictCount") == 0, "conflict gone after rebinding")

# action picker, description
ev('KeybindsStore.setActions("custom:0", [{id: "window.close", args: {}, layouts: ["scrolling"]}])')
check(ev(f"{adapter}.custom[0].actions[0].id") == "window.close", "action changed")
check(ev("KeybindsStore.row('custom:0').group") == "windows", "row moves to its action's group")
ev('KeybindsStore.setName("custom:0", "Close it")')
check(ev(f"{adapter}.custom[0].name") == "Close it", "description saved")

# add: a modal dialog, nothing is written before Save. Step 1 records the
# keys, step 2 picks the action ("Open app" shows the app list).
add = find("keybindsAdd")
dialog = find("keybindAddDialog")
h.eval(add, "clicked()")
QTest.qWait(300)
check(h.eval(dialog, "opened") is True, "Add opens the dialog")
check(ev(f"{adapter}.custom.length") == 2, "nothing is added before Save")
body = find("keybindAddBody")
check(body is not None and h.eval(body, "visible"), "the dialog is shown in the window overlay")
dpad = ev('w.findItem("keyCapture", w.findItem("keybindAddBody"))')
check(h.eval(dpad, "parent.recording") is True, "the dialog starts recording right away")
check(h.eval(dialog, "missing") == "keys", "keys come first")
key(dpad, Qt.Key_B, Qt.MetaModifier, "b")
QTest.qWait(100)
draft_keys = h.eval(dialog, "JSON.stringify(keys)")
check(draft_keys == '[{"modifiers":["SUPER"],"key":"B"}]', f"recorded Super+B: {draft_keys}")
check(h.eval(dialog, "missing") == "action", "then the action")
dpicker = ev('w.findAll(i => i.withHidden !== undefined && i.actionId !== undefined, w.findItem("keybindAddBody"))[0]')
check(h.eval(dpicker, "open") is True, "the action list opens after the keys")
check(h.eval(dpicker, "options[0].group") == "apps", "apps and commands come first")
h.eval(dpicker, "choose(options.find(o => o.id === 'apps.launch' && o.app === undefined))")
QTest.qWait(300)
check(h.eval(dialog, "missing") == "app", "Open app needs an app")
check(h.eval(find("keybindAddSave"), "enabled") is False, "Save waits for it")
option = ev('w.findItem("appOption:discord", w.findItem("keybindAddBody"))')
check(option is not None and h.eval(option, "visible"), "the app list is open")
h.eval(option, "children[3].clicked(null)")
check(h.eval(dialog, "missing") == "", "ready to save")
check("Apps" in h.eval(find("keybindAddStatus"), "text"), f"says where it goes: {h.eval(find('keybindAddStatus'), 'text')}")
uid = h.eval(dialog, "save()")
QTest.qWait(200)
check(uid == "custom:2" and h.eval(dialog, "opened") is False, "Save adds it and closes")
check(ev(f"JSON.stringify({adapter}.custom[2].actions[0].args)") == '{"app":"discord"}', "picked app saved by id")
check(ev(f"JSON.stringify({adapter}.custom[2].keys)") == '[{"modifiers":["SUPER"],"key":"B"}]', "keys saved")
check(ev("KeybindsStore.title(KeybindsStore.row('custom:2'))") == "Discord", "the row shows the app name")
check(ev("KeybindsStore.row('custom:2').group") == "apps", "app binds are in the apps group")
check(ev("KeybindsStore.highlightUid") == "custom:2", "the new bind is highlighted")
check(find("keybindRow:custom:2") is not None, "and listed")
ev('KeybindsStore.expandedUid = "custom:2"')
# the action picker finds apps by name too
QTest.qWait(200)
picker = ev('w.findAll(i => i.withHidden !== undefined && i.actionId !== undefined, w.findItem("keybindRow:custom:2"))[0]')
h.eval(picker, 'query = "tele"')
check(h.eval(picker, "options[0].app") == "org.telegram.desktop", "typing an app name offers opening it")
h.eval(picker, "choose(options[0])")
check(ev(f"{adapter}.custom[2].actions[0].args.app") == "org.telegram.desktop", "picked from the action search")
# Advanced: name, layouts, more combos/actions, raw dispatcher
QTest.qWait(200)
details = ev('w.findItem("keybindAdvanced", w.findItem("keybindRow:custom:2")).parent.parent')
check(h.eval(details, "advanced") is False, "advanced part closed for a simple bind")
picker = ev('w.findAll(i => i.withHidden !== undefined && i.actionId !== undefined, w.findItem("keybindRow:custom:2"))[0]')
h.eval(picker, 'query = "dispatcher"')
check(h.eval(picker, "options.length") == 0, "raw dispatcher only in Advanced")
h.eval(details, "advanced = true")
QTest.qWait(50)
picker = ev('w.findAll(i => i.withHidden !== undefined && i.actionId !== undefined, w.findItem("keybindRow:custom:2"))[0]')
h.eval(picker, 'query = "dispatcher"')
check(h.eval(picker, "options.map(o => o.id).join()") == "legacy.dispatcher", "Advanced offers the raw dispatcher")
ev('KeybindsStore.remove("custom:2")')
check(ev(f"{adapter}.custom.length") == 2, "remove deletes it")

# the dialog: the group follows the action (a window action lands in
# Windows), a taken combo is marked and kept, Return saves
h.eval(add, "clicked()")
QTest.qWait(300)
dpad = ev('w.findItem("keyCapture", w.findItem("keybindAddBody"))')
key(dpad, Qt.Key_Return, Qt.MetaModifier)
QTest.qWait(100)
clash = ev('w.findItem("clashNote", w.findItem("keybindAddBody"))')
check(h.eval(clash, "visible") is True and "kept" in h.eval(clash, "text"),
      f"the dialog marks the taken combo and keeps both ({h.eval(clash, 'text')})")
dpicker = ev('w.findAll(i => i.withHidden !== undefined && i.actionId !== undefined, w.findItem("keybindAddBody"))[0]')
h.eval(ev('w.findItem("actionFilter", w.findItem("keybindAddBody"))'), 'text = "fullscreen"')
h.eval(dpicker, 'query = "fullscreen"')
check(h.eval(dpicker, "options[0].id") == "window.fullscreen", "typing an action name finds it")
h.eval(dpicker, "choose(options[0])")
QTest.qWait(50)
check(h.eval(dialog, "groupId") == "windows", "a window action goes to Windows")
QGuiApplication.sendEvent(body, QKeyEvent(QEvent.KeyPress, Qt.Key_Return, Qt.NoModifier, "\r"))
QTest.qWait(200)
check(h.eval(dialog, "opened") is False and ev(f"{adapter}.custom.length") == 3, "Return saves")
check(ev("KeybindsStore.row('custom:2').group") == "windows", "listed under its action's group, not where Add is")
check(ev(f"{adapter}.custom[0].keys[0].key") == "Return" and ev(f"{adapter}.custom[2].keys[0].key") == "Return",
      "the other bind keeps its combo")
check(ev("KeybindsStore.conflictsOf('custom:2').length") > 0, "both are marked as a conflict")
row2 = find("keybindRow:custom:2")
check(row2 is not None and h.eval(row2, "highlighted") is True, "the new row flashes in its group")
ev('KeybindsStore.remove("custom:2")')

# cancel / Esc drops the draft and gives the compositor its binds back
h.eval(add, "clicked()")
QTest.qWait(300)
dpad = ev('w.findItem("keyCapture", w.findItem("keybindAddBody"))')
check(ev("KeybindsStore.recorders") == 1, "recording holds the compositor binds")
key(dpad, Qt.Key_Escape)
QTest.qWait(50)
check(ev("KeybindsStore.recorders") == 0, "Esc stops recording first")
check(h.eval(dialog, "opened") is True, "the dialog stays open")
QGuiApplication.sendEvent(body, QKeyEvent(QEvent.KeyPress, Qt.Key_Escape, Qt.NoModifier))
QTest.qWait(200)
check(h.eval(dialog, "opened") is False and ev(f"{adapter}.custom.length") == 2, "Esc again cancels, nothing added")
h.eval(add, "clicked()")
QTest.qWait(300)
key(ev('w.findItem("keyCapture", w.findItem("keybindAddBody"))'), Qt.Key_K, Qt.MetaModifier, "k")
h.eval(dialog, "cancel()")
QTest.qWait(200)
check(ev(f"{adapter}.custom.length") == 2 and ev("KeybindsStore.recorders") == 0, "Cancel discards")

# toolbar search filters the group cards: names, keys, empty state
ev('KeybindsStore.editorQuery = "close it"')
QTest.qWait(100)
check(find("keybindRow:custom:0") is not None and find("keybindRow:core:launcher") is None, "editor search filters")
check(h.eval(find("settingsSection:shell"), "visible") is False, "groups without matches are hidden")
check(h.eval(find("keybindsMatchCount"), "visible") is True, "the number of matches is shown")
ev('KeybindsStore.editorQuery = "super return"')
QTest.qWait(100)
check(find("keybindRow:custom:0") is not None and ev("KeybindsStore.visibleAll.length") == 1, "a key query finds the combo")
ev('KeybindsStore.editorQuery = "zzzz"')
QTest.qWait(100)
check(h.eval(find("keybindsEmpty"), "visible") is True, "empty state when nothing matches")
check(h.eval(find("settingsSection:windows"), "visible") is False, "no empty cards")
ev('KeybindsStore.editorQuery = ""')
QTest.qWait(100)
check(h.eval(find("settingsSection:windows"), "visible") is True and h.eval(find("keybindsEmpty"), "visible") is False,
      "clearing the search shows everything again")

# cheatsheet "edit" opens the row in the editor
ev('KeybindsStore.expandedUid = ""')
ev('KeybindsStore.requestEdit("core:system.screenshot")')
QTest.qWait(100)
check(ev("KeybindsStore.expandedUid") == "core:system.screenshot", "requestEdit expands the row")
check(ev("KeybindsStore.pendingEdit") == "", "pending edit consumed")

# --- Cheatsheet panel -----------------------------------------------------------
ev("visible = false")
sheet = h.find(win, "cheatsheet")
h.eval(sheet, "visible = true")
QTest.qWait(200)
total = h.eval(sheet, "filtered.length")
check(total > 10, "cheatsheet lists the binds")
h.eval(sheet, 'query = "screenshot"')
check(h.eval(sheet, "filtered.map(r => r.uid).indexOf('core:system.screenshot') !== -1"), "search finds a bind")
check(h.eval(sheet, "filtered.length") < total, "search narrows the list")
check(h.eval(sheet, "selectedUid") != "", "first hit selected")
search = ev('w.findItem("cheatsheetSearch")')
h.eval(search, "accepted()")
check(ev("w.edits.length") == 1, "Enter edits the selected bind")
h.eval(search, "escapePressed()")
check(ev("w.closes") == 1, "Esc closes")
h.eval(sheet, 'query = "zzzz"')
check(h.eval(sheet, "groups.length") == 0, "no groups without matches")

check(not [e for e in errors if "/widgets/" not in e], "QML errors:\n  " + "\n  ".join(errors))
print("keybinds-ui: ok")
