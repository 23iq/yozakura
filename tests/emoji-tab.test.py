"""Emoji tab (modules/widgets/dashboard/emoji) offscreen, inside the launcher.

Real tab and kit on tests/lib/tabs_env.py (emoji table from assets/, sample
recents): rows and recent strip, search, keyboard flow (recent strip
Left/Right, Shift+Enter tone options, Enter copies), clear-recent confirm.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from tabs_env import TabsEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = TabsEnv("emoji-tab")
h = env.h
win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.widgets.launcher
import qs.modules.services
Window {
    width: 700; height: 420; visible: true
    property var svc: ClipboardService
    property var vis: Visibilities
    LauncherView { objectName: "view"; anchors.fill: parent }
}""")
view = h.find(win, "view")
h.eval(view, "currentTab = 2")
QTest.qWait(600)
tab = h.eval(view, "tabLoader(2).item")
fails = []


def check(cond, msg, detail=""):
    print(("PASS " if cond else "FAIL ") + msg + (f"  {detail}" if detail and not cond else ""))
    if not cond:
        fails.append(msg)


def ev(expr):
    return h.eval(tab, expr)


def js(expr):
    return json.loads(ev("JSON.stringify(" + expr + ")"))


def calls():
    return json.loads(h.eval(win, "JSON.stringify(svc.calls)"))


check(ev("emojiData.length") > 1000, "emoji table loaded")
check(ev("hasRecentRow") and ev("model.count") == 51, "recent strip + 50 initial rows")
check(ev("recentModel.count") == 7, "seven recents")

ev("onDownPressed()")
check(ev("isAtRecent") and ev("selectedRecentIndex") == 0, "Down enters the recent strip")
ev("onRightPressed(); onRightPressed()")
check(ev("selectedRecentIndex") == 2, "Right moves in the strip")
ev("onLeftPressed()")
check(ev("selectedRecentIndex") == 1, "Left moves back")
ev("onDownPressed()")
check(ev("selectedIndex") == 1 and ev("selectedRecentIndex") == -1, "Down leaves the strip")

ev('searchText = "waving"')
QTest.qWait(50)
first = js("model.get(0).emojiData")
check(first["name"] == "waving hand" and not ev("hasRecentRow"), "search lists matches without the strip", first)
check(ev("selectedIndex") == 0, "first match selected")
ev("toggleOptions(selectedIndex, true)")
QTest.qWait(50)
check(ev("expandedItemIndex") == 0, "Shift+Enter opens tone options")
ev("onDownPressed(); onDownPressed()")
check(ev("selectedOptionIndex") == 2, "Down moves in tone options")
ev("activate()")
QTest.qWait(50)
copied = [c for c in calls() if c[0] == "copyAndTypeEmoji"]
check(copied and copied[-1][1] == "👋🏽", "Enter copies the toned emoji", copied)
check(js("recentEmojis[0]")["name"] == "waving hand (medium)", "copied emoji goes to recents")

ev('searchText = ""')
QTest.qWait(50)
check(ev("hasRecentRow"), "clearing the search brings the strip back")
ev("clearButtonConfirmState = true; clearRecentEmojis()")
QTest.qWait(50)
check(ev("recentEmojis.length") == 0 and not ev("hasRecentRow"), "clear recent empties the strip")
ev('searchText = "cat"')
QTest.qWait(50)
ev("collapseOptions(); activate()")
QTest.qWait(50)
check(calls()[-1][0] == "copyAndTypeEmoji" and h.eval(win, "vis.module") == "", "Enter on a row copies and closes")

print("\n" + ("OK" if not fails else f"{len(fails)} FAILED"))
sys.exit(1 if fails else 0)
