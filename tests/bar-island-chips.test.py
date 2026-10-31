"""The idle island's bar modules (modules/bar/modules/MediaChip, MicChip,
NotificationsChip) offscreen, real bar: hidden while the notch shows the
same content (no duplicates), shown with the notch off; the mic only while
muted or during its notice (with a label on a horizontal bar), the bell's
count and do-not-disturb (right click), the media popup's panel and empty
state, the compact glyph form on a vertical bar."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib import headless  # noqa: E402,F401
from island_env import IslandEnv  # noqa: E402
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SERVICES = {
    "MicrophoneStatus": """pragma Singleton
QtObject {
    property bool available: true; property bool muted: false
    property bool noticeVisible: false; property string noticeScreen: "DP-1"
}""",
    "Notifications": """pragma Singleton
QtObject {
    property var notchPopupList: []; property var popupList: []
    property var list: [{ id: 1 }, { id: 2 }]
    property bool silent: false; property var appNameList: []; property var groupsByAppName: ({})
    function toggleDnd() { silent = !silent }
    function showsOnScreen(name) { return true }
    function activateNotification(id) {} function discardNotifications(ids) {} function discardAllNotifications() {}
    function notifyInternal() {}
}""",
}


def bar(edge: str) -> dict:
    return {"frameEnabled": False, "containBar": False, "pinnedOnStartup": True, "panels": [{
        "id": "main", "edge": edge, "style": "classic",
        "groups": {"start": ["workspaces"], "end": ["media", "mic", "notifications", "clock"]}}]}


def find(item, name):
    if item.objectName() == name:
        return item
    for c in item.childItems():
        hit = find(c, name)
        if hit is not None:
            return hit
    return None


def scene(name: str, edge: str, notch: bool):
    env = IslandEnv(name, bar=bar(edge), notch={"enabled": notch, "position": "top"}, theme={"language": "ink"})
    env.h.module("qs.modules.services", SERVICES)
    win = PanelsEnv.scene(env, 1400, 800, windows=False)
    svc = env.h.load("import QtQuick\nimport qs.config\nimport qs.modules.services\nQtObject {}")
    QTest.qWait(500)
    return env.h, win, svc


def width(win, name: str) -> float:
    m = find(win.contentItem(), name)
    assert m is not None, name
    return m.width() if m.isVisible() else 0


# Notch on: the island shows media, bell and mic itself; the modules hide
h, win, svc = scene("island-chips-notch", "top", True)
h.eval(svc, "MicrophoneStatus.muted = true")
QTest.qWait(200)
for mod in ("media", "mic", "notifications"):
    assert width(win, mod) == 0, f"{mod}: shown twice with the notch on"

# Notch off: the bar modules take over
h.eval(svc, "Config.notch.enabled = false")
QTest.qWait(400)
for mod in ("media", "mic", "notifications"):
    assert width(win, mod) > 10, f"{mod}: no home with the notch off"
assert find(win.contentItem(), "mediaTitle").isVisible(), "horizontal: the title shows"

# Mic: hidden while live, back for its notice with the label
h.eval(svc, "MicrophoneStatus.muted = false")
QTest.qWait(200)
assert width(win, "mic") == 0, "a live mic stays hidden"
h.eval(svc, "MicrophoneStatus.noticeVisible = true")
QTest.qWait(200)
assert width(win, "mic") > 10 and find(win.contentItem(), "micLabel").isVisible(), "the notice shows a labelled chip"
h.eval(svc, "MicrophoneStatus.noticeScreen = 'HDMI-A-1'")
QTest.qWait(200)
assert width(win, "mic") == 0, "another screen's notice"

# Bell: the count, right click toggles do-not-disturb
assert h.eval(find(win.contentItem(), "bellCount"), "text") == "2"
bell = find(win.contentItem(), "notifications")
p = bell.mapToItem(None, bell.width() / 2, bell.height() / 2)
QTest.mouseClick(win, Qt.MouseButton.RightButton, Qt.KeyboardModifier.NoModifier, QPoint(round(p.x()), round(p.y())))
QTest.qWait(200)
assert h.eval(svc, "Notifications.silent") is True, "right click: do-not-disturb on"
assert h.eval(find(win.contentItem(), "bellGlyph"), "opacity") < 1, "do-not-disturb: the quiet bell"

# Media popup: the island's media panel, then the empty state
popup = find(win.contentItem(), "mediaPopup")
h.eval(popup, "open()")
QTest.qWait(500)
assert h.eval(popup, "panel !== null"), "the media panel loads in the popup"
h.eval(svc, "MprisController.activePlayer = null")
QTest.qWait(300)
assert find(win.contentItem(), "mediaEmpty").isVisible(), "no player: the empty state"
assert h.eval(popup, "panel === null")
win.close()

# Vertical bar: the compact glyph form (no title, no label)
h, win, svc = scene("island-chips-left", "left", False)
h.eval(svc, "MicrophoneStatus.muted = true; MicrophoneStatus.noticeVisible = true")
QTest.qWait(300)
assert width(win, "media") > 10 and not find(win.contentItem(), "mediaTitle").isVisible()
assert width(win, "mic") > 10 and not find(win.contentItem(), "micLabel").isVisible()
print("island bar chips: hidden with the notch, homed with it off, mic notice, bell DND, media popup, vertical")
h.exit(0)
