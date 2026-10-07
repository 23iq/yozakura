"""A hovered corner toast pauses its app group's timers and always resumes
them: on leave, and when the toast goes away under the pointer (no leave
event then), so the app's later popups never stay paused for good."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("corner-toast-hold")
h.module("qs.modules.services", {"Notifications": """pragma Singleton
QtObject {
    property var calls: []
    function pauseGroupTimers(app) { calls = calls.concat(["pause:" + app]) }
    function resumeGroupTimers(app) { calls = calls.concat(["resume:" + app]) }
    function discardNotifications(ids) {}
    function activateNotification(id) {}
    function attemptInvokeAction(id, a, b) {}
}"""})
h.module("qs.modules.components.kit", {
    "Space": "pragma Singleton\nQtObject { property int m: 8; property int hairline: 1 }",
    "Type": "pragma Singleton\nQtObject { property color track: \"gray\" }",
    "Surface": "Item { property int padding: 8; property string glassSurface; property real radius: 0 }",
    "Group": "Item { implicitHeight: childrenRect.height }",
})
h.module("qs.modules.components", {"Shadow": "Item {}"})
h.stub("ToastCard", "Item { property var notification; property int extra; property bool hovered; "
       "signal dismissRequested; signal actionInvoked(string identifier) }")
h.copy("modules/notifications/CornerToast.qml", siblings=False)
h.copy("modules/notifications/ToastModel.js", siblings=False)

root = h.load("""import QtQuick
import qs.modules.services
Item {
    width: 400; height: 300
    property alias loader: l
    readonly property var calls: Notifications.calls
    Loader {
        id: l
        width: 360
        sourceComponent: CornerToast {
            group: ({ appName: "mail", notifications: [] })
        }
    }
}""")


def calls():
    return h.eval(root, "calls.join(',')").split(",")


toast = h.eval(root, "loader.item")
h.eval(toast, "hold(true)")
assert calls() == ["pause:mail"], calls()
h.eval(toast, "hold(false)")
assert calls() == ["pause:mail", "resume:mail"], calls()
h.eval(toast, "hold(true)")
h.eval(root, "loader.active = false")
assert calls() == ["pause:mail", "resume:mail", "pause:mail", "resume:mail"], calls()
print("corner-toast-hold: ok")
