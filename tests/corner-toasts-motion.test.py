"""CornerToasts enter / glide motion in a real window (GL, private Xvfb):
every toast ends fully opaque and at full scale, drawn, also when its enter
is interrupted. ed3399e2 put the list transitions on Animators and every
toast stayed invisible; a displaced (or moved) toast still entering kept
its partial opacity and scale for good while `displaced` animated only x,y
(SettleTransition finishes them)."""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib import headless  # noqa: E402

headless.ensure(gl=True)
from lib.qmlharness import REPO, Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()
        time.sleep(0.002)


h = Harness("corner-toasts-motion")
h.singleton("qs.config", "Config", """QtObject {
    property QtObject notifications: QtObject { property string position: "top-left" }
    property QtObject bar: QtObject { property bool frameEnabled: false; property int frameThickness: 0 }
    property string notchPosition: "top"
}""")
h.module("qs.modules.services", {"Notifications": """pragma Singleton
QtObject {
    property string presentation: "corner"
    property string cornerPosition: "top-left"
    property var popupAppNameList: []
    property var popupGroupsByAppName: ({})
    property int clock: 0
    // A notification of `app`: newest first, like the real popup list
    function notify(app) {
        clock += 1;
        const g = Object.assign({}, popupGroupsByAppName);
        g[app] = { time: clock };
        popupGroupsByAppName = g;
        if (popupAppNameList.indexOf(app) === -1)
            popupAppNameList = popupAppNameList.concat([app]);
        else
            popupAppNameList = popupAppNameList.slice();
    }
    function showsOnScreen(n) { return true }
}"""})
h.module("qs.modules.shell", {"EdgeService": """pragma Singleton
QtObject {
    function freeCorner(screen, pref) { return "top-left" }
    function claimCorner(n, c) {}
}"""})
h.module("qs.modules.theme", {
    "Styling": "pragma Singleton\nQtObject { function fontSize(n) { return 14 } }",
    "Metrics": "pragma Singleton\nQtObject { property int toastW: 200 }",
    "Motion": """pragma Singleton
QtObject {
    property QtObject enter: QtObject { property int duration: 220; property int easing: Easing.OutBack; property real overshoot: 1.2 }
    property QtObject exit: QtObject { property int duration: 160; property int easing: Easing.InCubic; property real overshoot: 1 }
    property QtObject morph: QtObject { property int duration: 220; property int easing: Easing.OutCubic; property real overshoot: 1 }
}"""})
h.module("qs.modules.components.kit", {
    "Space": "pragma Singleton\nQtObject { property int xs: 4; property int s: 8; property int m: 12; property int xxl: 32 }",
    "SettleTransition": (REPO / "modules/components/kit/SettleTransition.qml").read_text(),
})
h.copy("modules/notifications/CornerToasts.qml", siblings=False)
h.stub("CornerToast", """Rectangle {
    objectName: "toast"
    property var group
    property bool stackUp
    height: 40
    color: "red"
}""")

root = h.load("""import QtQuick
import qs.modules.services
Item {
    width: 300; height: 300
    property alias toasts: t
    function notify(app) { Notifications.notify(app) }
    // [opacity, scale] of every live toast, top to bottom
    function states() {
        const list = t.hitbox, out = [];
        for (let i = 0; i < list.contentItem.children.length; i++) {
            const c = list.contentItem.children[i];
            if (c.objectName === "toast")
                out.push([c.y, +c.opacity.toFixed(2), +c.scale.toFixed(2)]);
        }
        return JSON.stringify(out.sort((a, b) => a[0] - b[0]).map(s => s.slice(1)));
    }
    CornerToasts {
        id: t
        anchors.fill: parent
        panel: ({ targetScreen: null, panelZones: ({}), dockEnabled: false })
        screenName: "DP-1"
    }
}""", auto_stub=False)

win = QQuickWindow()
win.resize(300, 300)
root.setParentItem(win.contentItem())
win.show()
pump(100)


def ev(expr):
    return h.eval(root, expr)


def settled(n):
    import json
    s = json.loads(ev("states()"))
    return len(s) == n and all(o == 1 and sc == 1 for o, sc in s), s


def drawn(n):
    img = win.grabWindow()
    # toasts sit from y 12 (gap), 40 px tall, 8 px apart; sample their middle
    px = [img.pixelColor(100, 12 + 20 + 48 * i) for i in range(n)]
    return all(c.red() > 200 and c.green() < 40 for c in px), [c.name() for c in px]


ev('notify("a")')
pump(600)
ok, s = settled(1)
check("one toast: ends opaque at full scale", ok, str(s))
ok, px = drawn(1)
check("one toast: drawn", ok, str(px))

# A second app while the first is still entering: the first is displaced
# mid-enter and must still end opaque at full scale
ev('notify("b")')
pump(60)
ev('notify("c")')
pump(700)
ok, s = settled(3)
check("toast displaced mid-enter: ends opaque at full scale", ok, str(s))
ok, px = drawn(3)
check("toasts displaced mid-enter: all drawn", ok, str(px))

# A newer notification of a shown app moves its toast to the top while
# that toast is still entering: "e" enters, "f" displaces it, then "e"
# again moves it back to the top mid-enter (the `move` transition)
ev('notify("e")')
pump(40)
ev('notify("f")')
pump(30)
ev('notify("e")')
pump(700)
ok, s = settled(5)
check("toast moved mid-enter: ends opaque at full scale", ok, str(s))
ok, px = drawn(5)
check("toasts moved mid-enter: all drawn", ok, str(px))

# SettleTransition with a delay (the stage notifications: the gap closes
# once a leaving card is out) still finishes a card displaced mid-enter
lv = h.load("""import QtQuick
import qs.modules.components.kit
ListView {
    width: 300; height: 300
    spacing: 8
    model: ListModel { id: m }
    function ins() { m.insert(0, { "k": m.count }) }
    function states() {
        const out = [];
        for (let i = 0; i < contentItem.children.length; i++) {
            const c = contentItem.children[i];
            if (c.objectName === "row")
                out.push([+c.opacity.toFixed(2), +c.x.toFixed(1)]);
        }
        return JSON.stringify(out);
    }
    delegate: Rectangle { objectName: "row"; width: 200; height: 40; color: "red" }
    add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
        NumberAnimation { property: "x"; from: 32; duration: 220 }
    }
    displaced: SettleTransition { duration: 220; delay: 60 }
    move: SettleTransition { duration: 220 }
}""", auto_stub=False)
lv.setParentItem(win.contentItem())
root.setVisible(False)
h.eval(lv, "ins()")
pump(60)
h.eval(lv, "ins()")
pump(30)
h.eval(lv, "ins()")
pump(800)
rows = h.eval(lv, "states()")
check("delayed settle: rows displaced mid-enter end opaque in place",
      rows == "[[1,0],[1,0],[1,0]]", rows)

print("CornerToasts motion:", "PASS" if ok_all else "FAIL")
h.exit(0 if ok_all else 1)
