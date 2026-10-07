"""A corner toast is one card sized to its content, in every visual language:
the card is exactly the content plus its padding (no empty band, nothing
spilling past its top), the toast's height is the card plus the peeking
stack, the stack sheets only show their strip past the card (top and bottom
corners), and a themed icon the theme lacks falls back to the app initial."""
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import LANGUAGES, KitEnv  # noqa: E402
from qmlharness import REPO  # noqa: E402

NOTIFICATIONS = """pragma Singleton
import QtQuick
QtObject {
    function pauseGroupTimers(a) {}
    function resumeGroupTimers(a) {}
    function discardNotifications(ids) {}
    function activateNotification(id) {}
    function attemptInvokeAction(id, ident, d) {}
}"""
QUICKSHELL = 'pragma Singleton\nimport QtQuick\nQtObject { function iconPath(name, check) { return "" } }'

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.notifications
Window {
    width: 420; height: 600; visible: true
    property alias single: one
    property alias stackDown: down
    property alias stackUp: up
    function n(i, ago) {
        return { id: i, appName: "Yozakura", summary: "This is a notification",
                 body: "Sent from Settings", time: Date.now() - ago, urgency: 1, actions: [],
                 image: "", appIcon: "preferences-system-notifications" }
    }
    Column {
        spacing: 40
        CornerToast { id: one; objectName: "single"; width: 360; group: ({ appName: "Yozakura", notifications: [n(1, 0)] }) }
        CornerToast { id: down; objectName: "stackDown"; width: 360; group: ({ appName: "Yozakura", notifications: [n(2, 0), n(3, 9), n(4, 99)] }) }
        CornerToast { id: up; objectName: "stackUp"; width: 360; stackUp: true; group: ({ appName: "Yozakura", notifications: [n(5, 0), n(6, 9)] }) }
    }
}"""

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


for lang in LANGUAGES:
    env = KitEnv(f"corner-toast-layout-{lang}", overrides={"theme": {"language": lang}})
    h = env.h
    qs = env.root / "qs"
    dst = qs / "modules/notifications"
    shutil.copytree(REPO / "modules/notifications", dst, dirs_exist_ok=True)
    act = qs / "modules/services/activities"
    act.mkdir(parents=True, exist_ok=True)
    shutil.copy(REPO / "modules/services/activities/NotificationProgress.js", act)
    h.module("qs.modules.services", {"Notifications": NOTIFICATIONS})
    h.module("Quickshell", {"Quickshell": QUICKSHELL})
    env._qmldir(dst, "qs.modules.notifications", only=["CornerToast", "ToastCard"])
    win = env.load(SCENE)

    for which in ("single", "stackDown", "stackUp"):
        toast = h.find(win, which)
        card = h.find(toast, "toastCard")
        content = h.find(toast, "toastContent")
        pad = h.eval(card, "padding")
        ch = h.eval(content, "implicitHeight")
        check(ch > 0, f"{lang}/{which}: content has a height")
        check(abs(h.eval(card, "height") - (ch + 2 * pad)) < 0.5,
              f"{lang}/{which}: card {h.eval(card, 'height')} == content {ch} + 2*{pad}")
        top = h.eval(content, "mapToItem(parent.parent, 0, 0).y")
        check(abs(top - pad) < 0.5, f"{lang}/{which}: content starts {top} inside the card (padding {pad})")
        depth = h.eval(toast, "depth")
        want = h.eval(card, "height") + depth * h.eval(toast, "peek")
        check(abs(h.eval(toast, "implicitHeight") - want) < 0.5, f"{lang}/{which}: toast height is card + stack")
        cy, cb = h.eval(card, "y"), h.eval(card, "y + height")
        raw = h.eval(toast, "JSON.stringify(children.filter(c => c.objectName === 'toastSheet').map(c => [c.y, c.y + c.height]))")
        sheets = json.loads(raw)
        check(len(sheets) == depth, f"{lang}/{which}: {depth} sheets, got {len(sheets)}")
        for y0, y1 in sheets:
            check(y0 >= cb - 0.5 or y1 <= cy + 0.5, f"{lang}/{which}: sheet {y0}..{y1} clear of the card {cy}..{cb}")

    art = h.find(h.find(win, "single"), "toastArt")
    check(h.eval(art, "source.toString()") == "", f"{lang}: a missing themed icon is no source")
    check(h.eval(art, "placeholderText") == "Y", f"{lang}: the placeholder is the app initial")

print("corner-toast-layout:", "OK" if not failures else f"{len(failures)} failure(s)")
sys.exit(1 if failures else 0)
