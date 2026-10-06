"""Corner toasts pick their corner: notifications.position "auto" asks
EdgeService.freeCorner (the corner the bar, dock and notch leave free) for the
panel's screen; an explicit corner is used as configured."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("corner-toasts")
h.singleton("qs.config", "Config", """QtObject {
    property QtObject notifications: QtObject { property string position: "auto" }
    property QtObject bar: QtObject { property bool frameEnabled: false; property int frameThickness: 0 }
    property string notchPosition: "top"
}""")
h.module("qs.modules.services", {"Notifications": """pragma Singleton
QtObject {
    property string presentation: "corner"
    property string cornerPosition: "top-right"
    property var popupAppNameList: []
    property var popupGroupsByAppName: ({})
    function showsOnScreen(n) { return true }
}"""})
h.module("qs.modules.shell", {"EdgeService": """pragma Singleton
QtObject {
    property var asked: null
    function freeCorner(screen, pref) { asked = screen; return screen && screen.width > 0 ? "bottom-left" : "top-right" }
}"""})
h.module("qs.modules.theme", {
    "Styling": "pragma Singleton\nQtObject { function fontSize(n) { return 14 } }",
    "Metrics": "pragma Singleton\nQtObject { property int toastW: 360 }",
    "Motion": """pragma Singleton
QtObject {
    property QtObject enter: QtObject { property int duration: 0; property int easing: Easing.OutCubic; property real overshoot: 1 }
    property QtObject exit: QtObject { property int duration: 0; property int easing: Easing.OutCubic; property real overshoot: 1 }
    property QtObject morph: QtObject { property int duration: 0; property int easing: Easing.OutCubic; property real overshoot: 1 }
}"""})
h.copy("modules/notifications/CornerToasts.qml", siblings=False)
h.stub("CornerToast", "Item { property var group }")

root = h.load("""import QtQuick
import qs.config
Item {
    width: 1600; height: 900
    property alias toasts: t
    function setPos(p) { Config.notifications.position = p }
    QtObject { id: screenObj; property int width: 1600; property int height: 900 }
    CornerToasts {
        id: t
        anchors.fill: parent
        panel: ({ targetScreen: screenObj, panelZones: ({}), dockEnabled: false })
        screenName: "DP-1"
    }
}""")

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


check(h.eval(root, "toasts.cornerPosition") == "bottom-left", "auto asks EdgeService.freeCorner")
check(h.eval(root, "toasts.side") == "left" and h.eval(root, "toasts.atBottom") is True, "auto corner drives the anchors")
check(h.eval(root, "toasts.autoCorner") is True, "auto by default")

# An explicit corner is used as configured (Notifications.cornerPosition)
h.eval(root, 'setPos("top-right")')
check(h.eval(root, "toasts.autoCorner") is False, "explicit corner is not auto")
check(h.eval(root, "toasts.cornerPosition") == "top-right", "explicit corner is used as configured")
check(h.eval(root, "toasts.side") == "right" and h.eval(root, "toasts.atBottom") is False, "explicit corner drives the anchors")

# auto without a panel screen falls back to the policy corner
h.eval(root, 'setPos("auto")')
h.eval(root, "toasts.panel = null")
check(h.eval(root, "toasts.cornerPosition") == "top-right", "no panel screen falls back to the policy corner")

print("corner-toasts:", "OK" if not failures else f"{len(failures)} failure(s)")
sys.exit(1 if failures else 0)
