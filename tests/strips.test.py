"""Notification strips (notifications.presentation "strips"): popups hang as
strips newest first, at most strips.maxVisible with a "+N" knot for the rest;
a strip opens into the card (the panel then wants the keyboard) and a
dismissed one leaves the row; the view is idle for other presentations."""
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from qmlharness import REPO  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

NOTIFICATIONS = """pragma Singleton
import QtQuick
QtObject {
    property string presentation: "strips"
    property var popupAppNameList: []
    property var popupGroupsByAppName: ({})
    property var discarded: []
    function showsOnScreen(n) { return true }
    function pauseGroupTimers(a) {}
    function resumeGroupTimers(a) {}
    function activateNotification(id) {}
    function attemptInvokeAction(id, ident, d) {}
    function add(n) {
        var g = Object.assign({}, popupGroupsByAppName);
        g[n.appName] = { appName: n.appName, time: n.time, notifications: [n] };
        popupGroupsByAppName = g;
        popupAppNameList = popupAppNameList.concat([n.appName]);
    }
    function discardNotifications(ids) {
        discarded = discarded.concat(ids);
        var g = {}, names = [];
        for (var k in popupGroupsByAppName) {
            if (ids.indexOf(popupGroupsByAppName[k].notifications[0].id) === -1) {
                g[k] = popupGroupsByAppName[k];
                names.push(k);
            }
        }
        popupGroupsByAppName = g;
        popupAppNameList = names;
    }
}"""
QUICKSHELL = 'pragma Singleton\nimport QtQuick\nQtObject { function iconPath(name, check) { return "" } }'

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.notifications.strips
Window {
    width: 1200; height: 700; visible: true
    property alias view: v
    function add(n) { Notifications.add(n) }
    StripsView {
        id: v
        anchors.fill: parent
        screenName: "T"
        panel: ({ panelZones: ({ top: 30 }), dockEnabled: false })
    }
}"""

env = KitEnv("strips", overrides={"theme": {"animDuration": 0},
                                   "notifications": {"strips": {"maxVisible": 2, "material": "paper"}}})
qs = env.root / "qs"
dst = qs / "modules/notifications"
shutil.copytree(REPO / "modules/notifications", dst, dirs_exist_ok=True)
(qs / "modules/services/activities").mkdir(parents=True, exist_ok=True)
shutil.copy(REPO / "modules/services/activities/NotificationProgress.js", qs / "modules/services/activities")
env.h.module("qs.modules.services", {"Notifications": NOTIFICATIONS})
env.h.module("Quickshell", {"Quickshell": QUICKSHELL})
env._qmldir(dst, "qs.modules.notifications", only=["ToastCard", "ToastGroup"])
env._qmldir(dst / "strips", "qs.modules.notifications.strips")

win = env.load(SCENE)
lst = env.h.find(win, "stripsList")
failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


def add(i, app, ago, **extra):
    n = {"id": i, "appName": app, "summary": app + " says hi", "body": "", "urgency": 1,
         "actions": [{"identifier": "ok", "text": "OK"}], "image": "", "appIcon": "", **extra}
    env.h.eval(win, f"add(Object.assign({json.dumps(n)}, {{ time: Date.now() - {ago} }}))")
    QTest.qWait(30)


def ev(expr):
    return env.h.eval(win, expr)


check(ev("view.active") is True, "active for presentation strips")
add(1, "Mail", 5000)
check(lst.property("count") == 1, "one strip")
add(2, "Slack", 0)
check(lst.property("count") == 2, "two strips")
check(ev("view.placed.keys[0]") == "Slack", "newest first")
check(ev("view.hitbox.width") > 0 and ev("view.hitbox.height") > 0, "hitbox covers the strips")
check(ev("view.hitbox.x + view.hitbox.width") <= 1200 and ev("view.hitbox.y") >= 30, "under the top bar, at the right")

# Over maxVisible: the oldest waits behind the knot
add(3, "Calendar", 100)
check(lst.property("count") == 2, "maxVisible strips hang")
check(ev("view.placed.overflow") == 1, "one behind the knot")
check(ev("view.placed.keys.indexOf('Mail')") == -1, "the oldest is the one that waits")

# Open the newest: card size, keyboard wanted
strip = env.h.eval(lst, "itemAtIndex(0)")
env.h.eval(strip, "toggle()")
QTest.qWait(30)
check(env.h.eval(strip, "expanded") is True, "toggle opens")
check(ev("view.wantsKeyboard") is True, "an open strip wants the keyboard")
check(abs(env.h.eval(strip, "frame.body.w") - ev("view.cardWidth")) < 1, "open strip is card wide")
check(env.h.eval(strip, "frame.body.h") > 0, "card has height")
env.h.eval(strip, "toggle()")
check(ev("view.wantsKeyboard") is False, "folded again")

# Dismiss (Delete / flick): the group is discarded and leaves the row
env.h.eval(strip, "dismiss('flick')")
QTest.qWait(50)
check(ev("Notifications.discarded.indexOf(2)") != -1, "dismiss discards the group")
check(ev("view.placed.keys.indexOf('Slack')") == -1, "dismissed strip leaves")
check(ev("view.placed.overflow") == 0 and lst.property("count") == 2, "the waiting one moves up")

# Other presentations: idle
ev("Notifications.presentation = 'corner'")
check(ev("view.active") is False and ev("view.placed.keys.length") == 0, "idle for corner toasts")
QTest.qWait(50)
check(lst.property("count") == 0, "no strip items remain when off")

print("strips:", "OK" if not failures else f"{len(failures)} failure(s)")
sys.exit(1 if failures else 0)
