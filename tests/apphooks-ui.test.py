"""Terminal & Apps status pills and the AppHooksService wiring, offscreen.

Real AppHooksService + AppThemingEditor against a scripted BackendService:
one pill per hook state, Connect applies, switching a toggle off reverts the
hook, switching one on ensures the enabled apps.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from apphooks_env import AppHooksEnv  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


env = AppHooksEnv("apphooks-ui", overrides={"theme": {"animDuration": 0}})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings.editors
import qs.modules.services
import qs.config
Window {
    width: 900; height: 700; visible: true
    AppThemingEditor { id: ed; objectName: "ed"; width: parent.width }
}""")
QTest.qWait(150)


def ev(expr):
    return h.eval(win, expr)


def calls(method):
    return json.loads(ev("JSON.stringify(BackendService.calls.filter(c => c.method === '%s'))" % method))


def find(root, name):
    for c in root.childItems():
        if c.objectName() == name:
            return c
        found = find(c, name)
        if found is not None:
            return found
    return None


ed = h.find(win, "ed")
check(len(calls("apphooks.status")) == 1, "status loaded once on start")
ens = calls("apphooks.ensure")
check(len(ens) == 1 and "kitty" in ens[0]["params"]["ids"] and "foot" in ens[0]["params"]["ids"], "ensure on start with enabled ids")
check(ev("AppHooksService.started") is True, "service started")


def pill(app):
    return find(ed, "appHook:" + app)


def chip_text(app):
    p = pill(app)
    t = find(p, "hookChipText")
    return t.property("text") if t is not None and find(p, "hookChip").property("visible") else ""


check(chip_text("kitty") == "Connected", "kitty connected pill: %r" % chip_text("kitty"))
check(chip_text("ghostty") == "Restart Ghostty to apply", "ghostty restart pill: %r" % chip_text("ghostty"))
check(chip_text("alacritty") == "Managed by your dotfiles", "alacritty managed pill")
tip = h.eval(pill("alacritty"), "tip")
check("import = [" in tip, "managed tooltip carries the exact line to add")
check(chip_text("discord") == "Couldn't connect", "discord error pill")
check(pill("qt").property("visible") is False, "absent app has no pill")
connect = find(pill("foot"), "hookConnect")
check(connect is not None and connect.property("visible") is True, "foot shows Connect")

h.eval(connect, "clicked()")
QTest.qWait(50)
ap = calls("apphooks.apply")
check(len(ap) == 1 and ap[0]["params"]["id"] == "foot", "Connect applies foot")

# Toggle kitty off: revert; toggle on again: ensure
before = len(calls("apphooks.ensure"))
h.eval(find(ed, "appTheme:kitty"), "toggled(false)")
QTest.qWait(80)
rv = calls("apphooks.revert")
check(len(rv) == 1 and rv[0]["params"]["id"] == "kitty", "toggling kitty off reverts kitty")
check(len(calls("apphooks.ensure")) == before + 1, "toggle change re-ensures")
check("kitty" not in calls("apphooks.ensure")[-1]["params"]["ids"], "disabled app not ensured")
h.eval(find(ed, "appTheme:kitty"), "toggled(true)")
QTest.qWait(80)
check(len(calls("apphooks.revert")) == 1, "turning on does not revert")
check("kitty" in calls("apphooks.ensure")[-1]["params"]["ids"], "re-enabled app ensured")

# An upgraded install starts with apps off (never edited unasked): Connect
# is offered anyway and switches the toggle on as it connects.
h.eval(find(ed, "appTheme:foot"), "toggled(false)")
QTest.qWait(80)
ev('AppHooksService.status = Object.assign({}, AppHooksService.status, {foot: {id: "foot", state: "disconnected"}})')
QTest.qWait(30)
connect = find(pill("foot"), "hookConnect")
check(connect is not None and connect.property("visible") is True, "Connect shows for a switched-off, disconnected app")
applies = len(calls("apphooks.apply"))
h.eval(connect, "clicked()")
QTest.qWait(80)
check(ev("Config.apps.theming.foot") is True, "Connect switches the toggle on")
check(len(calls("apphooks.apply")) == applies + 1 and calls("apphooks.apply")[-1]["params"]["id"] == "foot", "Connect applies")

if failures:
    print(f"{len(failures)} failure(s)")
    sys.exit(1)
print("apphooks-ui: ok")
