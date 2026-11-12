#!/usr/bin/env python3
"""Settings > Terminal > When a terminal opens (modules/terminal/
FastfetchSection): the greeting switch, the live fastfetch preview, the
sample + install action while fastfetch is missing, the look and logo
chips, the logo file field and the shell notices, offscreen.

The real TerminalLookService, ExtrasService and FetchModel.js run against a
scripted BackendService (tests/lib/terminal_env.py).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from extras_env import full_catalog  # noqa: E402
from terminal_env import STATUS, TerminalEnv  # noqa: E402

from PySide6.QtCore import QPointF, Qt  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from waits import pump, wait_stable, wait_until  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


FETCH_PRESETS = [
    {"id": "sakura", "name": "Sakura", "description": "term.fetch.preset.sakura.desc", "logo": True},
    {"id": "boxed", "name": "Boxed", "description": "term.fetch.preset.boxed.desc", "logo": True},
    {"id": "minimal", "name": "Minimal", "description": "term.fetch.preset.minimal.desc", "logo": False},
    {"id": "own", "name": "", "description": "term.fetch.preset.own.desc", "logo": False, "own": True},
]
SHELLS_OFF = [{"shell": "fish", "state": "off"}, {"shell": "bash", "state": "off"}, {"shell": "zsh", "state": "absent"}]
GREETING = {"on": False, "fastfetchInstalled": False, "ownConfig": False, "shells": SHELLS_OFF}
SAMPLE = {"lines": [[{"text": "▗▄▖ ", "fg": "#f5adff"}, {"text": "user", "fg": "#f5adff", "bold": True},
                     {"text": "@yozakura"}], [{"text": "os  Arch Linux"}]],
          "exact": False, "reason": "fastfetch_missing"}
status = {**STATUS, "greeting": GREETING}

env = TerminalEnv("terminal-fetch-ui", catalog=full_catalog(), status=status,
                  overrides={"theme": {"animDuration": 0}},
                  replies={"term.fetch.presets": FETCH_PRESETS, "term.fetch.preview": SAMPLE,
                           "extras.status": {"fastfetch": {"id": "fastfetch", "state": "missing"}}})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.terminal
import qs.modules.services
import qs.modules.settings.store
import qs.config
Window {
    width: 1000; height: 1600; visible: true
    Column {
        objectName: "col"
        width: parent.width
        FastfetchSection { objectName: "section"; width: parent.width; animate: false }
    }
}""")
QTest.qWait(150)


def ev(expr, obj=None):
    return h.eval(obj or win, expr)


def js(expr, obj=None):
    return json.loads(ev("JSON.stringify(%s)" % expr, obj))


def calls(method):
    return js("BackendService.calls.filter(c => c.method === '%s')" % method)


def item(root, name):
    for c in root.childItems():
        if c.objectName() == name:
            return c
        found = item(c, name)
        if found is not None:
            return found
    return None


def find(name):
    return item(win.findChild(QQuickItem, "col"), name)


def visible(it) -> bool:
    return it is not None and bool(it.isVisible())


def click(it) -> None:
    wait_stable(lambda: it.mapToScene(QPointF(it.width() / 2, it.height() / 2)), stable_ms=40)
    p = it.mapToScene(QPointF(it.width() / 2, it.height() / 2)).toPoint()
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, p)
    QTest.qWait(40)


def chip(row, label):
    """The chip of a SelectorControl whose text is label."""
    stack = [find(row)]
    while stack:
        it = stack.pop()
        if it is None:
            continue
        if it.property("text") == label and it.property("active") is not None:
            return it
        stack.extend(it.childItems())
    return None


wait_until(lambda: len(calls("term.fetch.preview")) >= 1)
first = calls("term.fetch.preview")[0]["params"]
check(first["preset"] == "own" and first["logo"] == "sakura", "the preview asks for the configured look: %s" % first)
check(len(first.get("ansi", [])) == 16, "the preview sends the terminal's 16 colours")
check(ev("Config.terminal.greeting") == "none", "the greeting starts off")
check(ev("checked", find("fetchSwitch")) is False, "the switch shows off")

# fastfetch missing: the sample with an install action
wait_until(lambda: visible(find("fetchSampleNotice")))
check(visible(find("fetchSampleNotice")), "a sample preview says so")
check(visible(find("installFastfetchButton")), "fastfetch missing: Install fastfetch")
lines = js("greetingLines", find("fetchPreview"))
check(lines and lines[0][1]["text"] == "user", "the preview draws the greeting lines: %s" % lines)

# own look: the logo choice does not apply
check(not ev("enabled", find("fetchLogoChips")), "own look: logo chips disabled")
check(not visible(find("fetchLogoPath")), "no logo path field unless custom")

# switching on: own without a fastfetch config of the user's becomes sakura,
# fastfetch is queued
click(find("fetchSwitch"))
check(ev("Config.terminal.greeting") == "fastfetch", "the switch turns the greeting on")
check(len(calls("term.fetch.allow")) == 1, "switched on by the user: every shell (term.fetch.allow)")
check(ev("Config.terminal.fastfetchPreset") == "sakura", "plain fastfetch without an own config: the sakura look")
inst = calls("extras.install")
check(inst and inst[-1]["params"]["ids"] == ["fastfetch"], "turning it on with fastfetch missing queues it: %s" % inst)
check(any(c["params"].get("preset") == "sakura" for c in calls("term.fetch.preview")), "the new look is previewed")
check(ev("enabled", find("fetchLogoChips")) is True, "sakura look: logo chips enabled")

# the look chips write the preset; minimal blocks the logo
click(chip("fetchPresetChips", "Boxed"))
check(ev("Config.terminal.fastfetchPreset") == "boxed", "a look chip writes terminal.fastfetchPreset")
click(chip("fetchPresetChips", "Minimal"))
check(not ev("enabled", find("fetchLogoChips")), "minimal: no logo")
click(chip("fetchPresetChips", "Sakura"))

# custom logo: the path field, a problem from the status, the picture note
click(chip("fetchLogoChips", "Your own"))
check(ev("Config.terminal.fastfetchLogo") == "custom", "a logo chip writes terminal.fastfetchLogo")
check(visible(find("fetchLogoPath")), "custom: the file field shows")
ev("SettingsStore.set('terminal.fastfetchLogoPath', '/home/user/me.png')")
pump(100)
check(any(c["params"].get("logoPath") == "/home/user/me.png" for c in calls("term.fetch.preview")),
      "the custom file is previewed")
on = {**STATUS, "greeting": {**GREETING, "on": True, "fastfetchInstalled": True, "logoError": "logo_missing",
                             "shells": [{"shell": "fish", "state": "on"},
                                        {"shell": "bash", "state": "foreign", "file": "/home/user/.bashrc"},
                                        {"shell": "zsh", "state": "managed", "file": "/home/user/.zshrc"}]}}
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'term.status': %s, "
   "'term.fetch.preview': %s})" % (json.dumps(on), json.dumps({"lines": SAMPLE["lines"], "exact": True,
                                                                "imageLogo": True})))
ev("TerminalLookService.refreshStatus()")
wait_until(lambda: visible(find("fetchLogoError")))
check(visible(find("fetchLogoError")), "a logo file problem is shown")
check("cannot be read" in ev("message", find("fetchLogoError")), "it says what is wrong: %r" % ev("message", find("fetchLogoError")))
wait_until(lambda: visible(find("fetchImageNotice")))
check(visible(find("fetchImageNotice")), "a picture logo says where it shows")
check(not visible(find("fetchSampleNotice")), "real fastfetch output: no sample notice")
foreign = find("fetchShellNotice:bash")
check(visible(foreign) and "~/.bashrc" in ev("title", foreign), "a shell running fetch itself is named")
check(visible(find("fetchShellNotice:zsh")), "a read-only rc file is named")
broken = {**on, "greeting": {**on["greeting"], "shells": [{"shell": "fish", "state": "on"},
                                                          {"shell": "bash", "state": "broken", "file": "/home/user/.bashrc"}]}}
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'term.status': %s})" % json.dumps(broken))
ev("TerminalLookService.refreshStatus()")
wait_until(lambda: "edited" in (ev("title", find("fetchShellNotice:bash")) or ""))
check("~/.bashrc" in (ev("title", find("fetchShellNotice:bash")) or "") and "edited" in ev("title", find("fetchShellNotice:bash")),
      "edited markers are named")
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'term.status': %s})" % json.dumps(on))
ev("TerminalLookService.refreshStatus()")
wait_until(lambda: visible(find("fetchShellNotice:zsh")))
check("fish" in ev("subtitle", find("fetchSwitchRow")), "the switch row says where it shows")

# on from before the update: fish only until the user lets it into bash / zsh
check(not visible(find("fetchHeldNotice")), "no held shells: no notice")
held = {**STATUS, "greeting": {**GREETING, "on": True, "fastfetchInstalled": True,
                               "shells": [{"shell": "fish", "state": "on"},
                                          {"shell": "bash", "state": "held", "file": "/home/user/.bashrc"},
                                          {"shell": "zsh", "state": "held", "file": "/home/user/.zshrc"}]}}
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'term.status': %s})" % json.dumps(held))
ev("TerminalLookService.refreshStatus()")
wait_until(lambda: visible(find("fetchHeldNotice")))
check(visible(find("fetchHeldNotice")), "held shells are named")
check("bash, zsh" in ev("message", find("fetchHeldNotice")), "it names them: %r" % ev("message", find("fetchHeldNotice")))
allows = len(calls("term.fetch.allow"))
click(find("fetchAllowButton"))
check(len(calls("term.fetch.allow")) == allows + 1, "the button lets the greeting into them")

# off
click(find("fetchSwitch"))
check(ev("Config.terminal.greeting") == "none", "the switch turns it off")
check(not visible(find("fetchShellNotice:bash")), "shell notices only while on")
pump(500)
check(len(calls("term.apply")) >= 1, "changes reach the backend (term.apply)")

# the setup wizard switches it on: every shell as well
allows = len(calls("term.fetch.allow"))
ev("TerminalLookService.enableGreeting('sakura', 'sakura')")
check(ev("Config.terminal.greeting") == "fastfetch", "the wizard turns the greeting on")
check(len(calls("term.fetch.allow")) == allows + 1, "the wizard lets it into every shell")

if failures:
    print(f"{len(failures)} failure(s)")
    h.exit(1)
print("terminal-fetch-ui: ok")
h.exit(0)
