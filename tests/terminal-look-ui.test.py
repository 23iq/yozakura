#!/usr/bin/env python3
"""Terminal look (modules/terminal + Settings > Terminal & Apps): prompt
gallery cards, live kitty preview, approximate-preview install action,
fish status, cursor chips, offscreen.

The real TerminalLookService, ExtrasService and TermModel.js run against a
scripted BackendService (tests/lib/terminal_env.py).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from terminal_env import TerminalEnv, sample_previews  # noqa: E402

from PySide6.QtCore import QPointF, Qt  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


env = TerminalEnv("terminal-look-ui", overrides={"theme": {"animDuration": 0}})
h = env.h
win = h.load("""
import QtQuick
import QtQuick.Window
import qs.modules.terminal
import qs.modules.settings.editors
import qs.modules.services
import qs.config
import qs.modules.theme
Window {
    width: 1000; height: 1500; visible: true
    Column {
        objectName: "col"
        width: parent.width
        TerminalLookSection { objectName: "section"; width: parent.width; animate: false }
        CursorShapeChips { objectName: "chips" }
    }
}""")
QTest.qWait(100)


def ev(expr, obj=None):
    return h.eval(obj or win, expr)


def js(expr, obj=None):
    return json.loads(ev("JSON.stringify(%s)" % expr, obj))


def calls(method):
    return js("BackendService.calls.filter(c => c.method === '%s')" % method)


def item(root, name):
    """Repeater delegates are not QObject children: walk the visual tree."""
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
    p = it.mapToScene(QPointF(it.width() / 2, it.height() / 2)).toPoint()
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, p)
    QTest.qWait(40)


def preview_text(name="inputLine"):
    line = find(name)
    return "".join(s["text"] for s in js("spans", line)) if line is not None else None


# load: presets, status, one preview per card for the configured engine
check(len(calls("term.presets")) == 1, "the section loads the presets once")
check(len(calls("term.status")) >= 1, "the section loads the status")
asked = sorted({(c["params"]["engine"], c["params"]["prompt"]) for c in calls("term.preview")})
check(asked == [("starship", "plain"), ("starship", "sakura-powerline"), ("starship", "two-line-box")],
      "every card asks its starship preview: %s" % asked)
for pid in ("sakura-powerline", "two-line-box", "plain"):
    check(find("promptCard:" + pid) is not None, "card for %s" % pid)
check(ev("selected", find("promptCard:sakura-powerline")) is True, "the configured prompt is selected")
check(visible(item(find("promptCard:plain"), "nerdFreeBadge")), "plain shows the Nerd-free badge")
check(not visible(item(find("promptCard:sakura-powerline"), "nerdFreeBadge")), "Nerd Font presets show no badge")

# the big preview draws the configured prompt + the sample command
check(preview_text().endswith("❯ ") , "input line ends with the prompt char: %r" % preview_text())
check("~/yozakura" in preview_text(), "the preview shows the prompt path")
check(preview_text("rightPrompt") == "3s", "the right prompt is drawn: %r" % preview_text("rightPrompt"))
check(visible(find("offNotice")), "the prompt is off: the 'current prompt is kept' notice shows")
check(not visible(find("approxNotice")), "exact preview: no approximate notice")
check(not visible(find("fishNotice")), "fish is the login shell: no fish notice")

# picking a card: prompt + enabled written and saved, preview follows
click(find("promptCard:plain"))
check(ev("Config.terminal.prompt") == "plain", "clicking a card sets terminal.prompt")
check(ev("Config.terminal.enabled") is True, "clicking a card switches the prompt on")
check("terminal" in js("Config.saved"), "the terminal domain is saved")
check(ev("selected", find("promptCard:plain")) is True, "the clicked card is selected")
check(preview_text().startswith("~/yozakura on main > "), "the preview shows the picked prompt: %r" % preview_text())
check(not visible(find("rightPrompt")), "plain has no right prompt")
check(not visible(find("offNotice")), "the off notice hides once a prompt is on")
check(calls("extras.install") == [], "an installed engine is not installed again")

# cursor chips
click(item(find("chips"), "cursorChip:block"))
check(ev("Config.terminal.cursorShape") == "block", "cursor chip writes terminal.cursorShape")
cursor = find("cursor")
check(abs(ev("width", cursor) - ev("cell", find("terminalPreview"))) < 0.01, "block cursor is one cell wide")
click(item(find("chips"), "cursorChip:underline"))
check(ev("Config.terminal.cursorShape") == "underline", "underline chip")
check(ev("height", find("cursor")) <= 3, "underline cursor is a thin bar")

# approximate preview (oh-my-posh missing): install action
ev("BackendService.previews = %s" % json.dumps(sample_previews(exact=False, engine="ohmyposh")))
ev("Config.terminal.engine = 'ohmyposh'")
QTest.qWait(60)
check([c["params"]["ids"] for c in calls("extras.install")] == [["oh-my-posh"]],
      "switching a prompt that is on to a missing engine queues it: %s" % calls("extras.install"))
check(visible(find("approxNotice")), "an approximate preview shows the notice")
btn = find("installEngineButton")
check(visible(btn), "a missing engine offers its install")
check("Oh My Posh" in ev("text", btn) or "oh-my-posh" in ev("text", btn), "the button names the engine: %r" % ev("text", btn))
click(btn)
check(calls("extras.install")[-1]["params"]["ids"] == ["oh-my-posh"], "install queues oh-my-posh: %s" % calls("extras.install"))
n = len(calls("extras.install"))
click(find("promptCard:two-line-box"))
check(len(calls("extras.install")) == n + 1 and calls("extras.install")[-1]["params"]["ids"] == ["oh-my-posh"],
      "picking a prompt with the engine missing queues the engine")
check(len(js("promptLines", find("terminalPreview"))) == 2, "two-line preset: two prompt lines")
n = len(calls("extras.install"))
ev("Config.terminal.enabled = false")
ev("Config.terminal.enabled = true")
check(len(calls("extras.install")) == n + 1, "switching the prompt on with the engine missing queues it")

# palette change: previews fetched again
before = len(calls("term.preview"))
ev("Colors.primary = '#00ff00'")
QTest.qWait(800)
check(len(calls("term.preview")) > before, "a palette change re-renders the previews")

# fish not the login shell -> chsh
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'term.status': %s})"
   % json.dumps({**js("TerminalLookService.status"), "fishIsLoginShell": False, "foreignPromptInit": True,
                 "foreignFile": "/home/user/.config/fish/config.fish"}))
ev("TerminalLookService.refreshStatus()")
QTest.qWait(40)
check(visible(find("fishNotice")), "fish not the login shell: notice shows")
check(visible(find("foreignNotice")), "another prompt init in config.fish: warning shows")
check("~/.config/fish/config.fish" in ev("title", find("foreignNotice")), "the warning names the file")
click(find("makeFishButton"))
check(calls("extras.setLoginShell")[-1]["params"] == {"shell": "/usr/bin/fish"}, "make default runs chsh to fish")

# fish missing -> install fish, then chsh once installed
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'term.status': %s})"
   % json.dumps({**js("TerminalLookService.status"), "fishInstalled": False}))
ev("TerminalLookService.refreshStatus()")
QTest.qWait(40)
shells = len(calls("extras.setLoginShell"))
click(find("makeFishButton"))
check(calls("extras.install")[-1]["params"]["ids"] == ["fish"], "missing fish is installed first")
check(len(calls("extras.setLoginShell")) == shells, "no chsh before fish is installed")
ev("BackendService.replies = Object.assign({}, BackendService.replies, {'term.status': %s})"
   % json.dumps({**js("TerminalLookService.status"), "fishInstalled": True}))
ev("BackendService.emit('extras.status', {'fish': {'id': 'fish', 'state': 'installed'}})")
QTest.qWait(1000)
check(len(calls("extras.setLoginShell")) == shells + 1, "fish installed: chsh follows")

if failures:
    print(f"{len(failures)} failure(s)")
    h.exit(1)
print("terminal-look-ui: ok")
h.exit(0)
