"""Special workspaces UI, offscreen: the settings page (templates, cards,
rename, accent/icon, app picker and app rows, binds through the keybinds
recorder) and the special rows in the keybinds model (cheatsheet +
conflicts). Real modules/settings, modules/keybinds and modules/specials
logic on tests/lib/settings_env.py.
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
from settings_env import SettingsEnv, default_binds  # noqa: E402

SPECIALS = [
    {"id": "telegram", "name": "Telegram", "icon": "telegram", "accent": "primary",
     "toggle": {"modifiers": ["SUPER"], "key": "S"}, "send": {"modifiers": ["SUPER", "ALT"], "key": "S"},
     "preload": False, "apps": [{"id": "org.telegram.desktop", "name": "Telegram", "icon": "telegram",
                                 "match": "org.telegram.desktop", "command": "", "ifRunning": "nothing", "rule": False}]},
    {"id": "discord", "name": "Discord", "icon": "chatDots", "accent": "tertiary",
     "toggle": {"modifiers": ["SUPER"], "key": "D"}, "send": {"modifiers": ["SUPER", "ALT"], "key": "D"},
     "preload": True, "apps": [{"id": "discord", "name": "Discord", "icon": "discord", "match": "discord",
                                "command": "/usr/bin/discord --url --", "ifRunning": "move", "rule": True}]},
    {"id": "dev", "name": "Dev", "icon": "code", "accent": "secondary",
     "toggle": {"modifiers": ["SUPER"], "key": "C"}, "send": {"modifiers": ["SUPER", "ALT"], "key": "C"},
     "preload": False, "apps": []},
]

binds = default_binds()
binds["custom"] = [{"name": "Close", "keys": [{"modifiers": ["SUPER"], "key": "C"}],
                    "actions": [{"id": "window.close", "args": {}, "layouts": []}], "enabled": True}]
env = SettingsEnv("specials-ui", binds=binds, overrides={"specials": {"workspaces": SPECIALS}})
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
import qs.modules.keybinds
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1180; height: 900; visible: true; color: "black"
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function list() { return JSON.stringify(SettingsStore.get("specials.workspaces")) }
    function rows() { return JSON.stringify(KeybindsStore.rows.filter(r => r.kind === "special").map(r => r.uid)) }
    function conflicts(uid) { return JSON.stringify(KeybindsStore.conflictsOf(uid)) }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr: str):
    return h.eval(shell, expr)


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def items() -> list:
    return json.loads(ev("w.list()"))


ev('select("specials")')
QTest.qWait(600)
for sid in ("telegram", "discord", "dev"):
    check(ev(f'w.findItem("specialCard:{sid}") !== null'), f"card for {sid}")
for t in ("chat", "music", "dev", "notes", "custom"):
    check(ev(f'w.findItem("template:{t}") !== null'), f"template {t}")

# Keybinds model: the specials' binds are rows of kind "special" and clash
# with other binds (SUPER+C is the custom "Close").
rows = json.loads(ev("w.rows()"))
check(rows == ["special:telegram:toggle", "special:telegram:send", "special:discord:toggle",
               "special:discord:send", "special:dev:toggle", "special:dev:send"], f"special bind rows {rows}")
check(len(json.loads(ev('w.conflicts("special:dev:toggle")'))) == 1, "SUPER+C clash reported")

# Templates: a custom one is "Special 1", expanded; the next "Special 2".
ev('w.findItem("template:custom").clicked()')
QTest.qWait(100)
names = [i["name"] for i in items()]
check(names[-1] == "Special 1", f"custom template name {names}")
ev('w.findItem("template:custom").clicked()')
QTest.qWait(100)
check([i["name"] for i in items()][-1] == "Special 2", "second custom is Special 2")
new_id = items()[-1]["id"]
check(ev(f'w.findItem("specialCard:{new_id}").expanded') is True, "a new special opens expanded")

# Rename through the card; duplicates are flagged, not written silently.
card = f'w.findItem("specialCard:{new_id}")'
ev(f'{card}.patched({{"name": "Music"}})')
QTest.qWait(50)
check(items()[-1]["name"] == "Music", "renamed")
ev(f'{card}.patched({{"name": "telegram"}})')
QTest.qWait(50)
check(ev(f'{card}.problem') != "", "duplicate name shows a problem")
ev(f'{card}.patched({{"name": "Music", "accent": "cyan", "icon": "musicNotes"}})')
QTest.qWait(50)
last = items()[-1]
check((last["accent"], last["icon"]) == ("cyan", "musicNotes"), "accent + icon")

# App picker (AppSearch fixture) adds an app; rows edit it.
ev(f'{card}.appAdded({{"id": "discord", "name": "Discord", "icon": "discord", "match": "discord", '
   f'"command": "discord", "ifRunning": "nothing", "rule": false}})')
QTest.qWait(50)
ev(f'{card}.appPatched(0, {{"ifRunning": "move", "rule": true}})')
QTest.qWait(50)
app = items()[-1]["apps"][0]
check((app["ifRunning"], app["rule"]) == ("move", True), f"app row edit {app}")
search = ev('w.findItem("appSearch")')
check(search is not None, "app search field")

# Binds recorded on the card land in specials.json and in the keybinds rows.
ev(f'{card}.patched({{"toggle": {{"modifiers": ["SUPER"], "key": "M"}}}})')
QTest.qWait(50)
check(f"special:{new_id}:toggle" in json.loads(ev("w.rows()")), "new bind row")
ev(f'{card}.appRemoved(0)')
ev(f'{card}.removeRequested()')
QTest.qWait(50)
check(len(items()) == 4, "removed")

out = Path(sys.argv[1]) if len(sys.argv) > 1 else None
if out:
    out.mkdir(parents=True, exist_ok=True)
    ev('w.findItem("specialCard:discord").expanded = true')
    QTest.qWait(400)
    win.grabWindow().save(str(out / "specials-settings.png"))

check(not errors, "QML errors: " + "\n".join(errors[:5]))
print("specials-ui: ok")
