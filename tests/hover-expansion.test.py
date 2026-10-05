"""Notch panel timing (modules/widgets/defaultview/panels/NotchPanelController.qml)
offscreen: hover delays, crossing, switching between segments, suspension,
availability, click mode and auto/modal panels (voice)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("notch-panels")
h.singleton("qs.config", "Config", "QtObject { property QtObject notch: QtObject { property int hoverExpandDelay: 30; property int hoverCollapseDelay: 40 } }")
h.copy("modules/widgets/defaultview/panels/NotchPanelController.qml")
c = h.load("""
import QtQuick
NotchPanelController {
    available: ({ media: true, transfers: true, privacy: false })
}
""")


def is_open():
    return h.eval(c, "openPanel")


c.setProperty("hoverTarget", "media")
QTest.qWait(10)
assert is_open() == "", "must not open before the delay"
QTest.qWait(60)
assert is_open() == "media", "resting on the media title opens the media panel"

c.setProperty("hoverTarget", "")
QTest.qWait(10)
assert is_open() == "media", "crossing to the panel keeps it"
c.setProperty("hold", True)
QTest.qWait(80)
assert is_open() == "media", "pointer inside the panel holds it"
c.setProperty("hold", False)

c.setProperty("hoverTarget", "transfers")
QTest.qWait(10)
assert is_open() == "media", "switching also waits for a deliberate rest"
QTest.qWait(60)
assert is_open() == "transfers", "resting on another segment switches panels"

c.setProperty("hoverTarget", "privacy")
QTest.qWait(80)
assert is_open() == "", "an unavailable target behaves like no target and collapses"

c.setProperty("hoverTarget", "media")
QTest.qWait(80)
c.setProperty("suspended", True)
assert is_open() == "", "launcher transitions close immediately"
QTest.qWait(80)
assert is_open() == "", "and nothing reopens while suspended"
c.setProperty("suspended", False)
QTest.qWait(80)
assert is_open() == "media"
h.eval(c, "available = ({ media: false, transfers: true })")
assert is_open() == "", "a panel closes when its content goes away"

# click mode
h.eval(c, "available = ({ media: true, transfers: true })")
c.setProperty("hoverTarget", "")
c.setProperty("mode", "click")
QTest.qWait(80)
c.setProperty("hoverTarget", "media")
QTest.qWait(80)
assert is_open() == "", "hover does nothing in click mode"
h.eval(c, "toggle('media')")
assert is_open() == "media"
h.eval(c, "toggle('transfers')")
assert is_open() == "transfers", "clicking another segment switches"
c.setProperty("hoverTarget", "")
QTest.qWait(80)
assert is_open() == "transfers", "click mode does not close on leave"
h.eval(c, "toggle('transfers')")
assert is_open() == "", "clicking the same segment closes"
h.eval(c, "toggle('media'); close()")
assert is_open() == ""

# auto + modal panel (voice): opens by itself, wins over hover/click,
# survives leaving, dismissal keeps it closed until it goes away.
h.eval(c, "mode = 'hover'; hoverTarget = ''; hold = false")
QTest.qWait(80)
dismissed = []
c.dismissed.connect(dismissed.append)
h.eval(c, "available = ({ media: true, transfers: true, voice: true })")
assert is_open() == "voice", "an auto panel opens immediately"
assert h.eval(c, "modal") and h.eval(c, "autoOpen"), "voice is modal and auto"
c.setProperty("hoverTarget", "media")
QTest.qWait(80)
assert is_open() == "voice", "hovering a segment does not switch away from it"
c.setProperty("hoverTarget", "")
QTest.qWait(80)
assert is_open() == "voice", "leaving does not close it"
h.eval(c, "toggle('media')")
assert is_open() == "voice", "clicks do not switch away from it"
h.eval(c, "close()")
assert is_open() == "" and dismissed == ["voice"], "Esc/click outside dismisses it (and says so)"
QTest.qWait(80)
assert is_open() == "", "a dismissed auto panel stays closed while still available"
h.eval(c, "available = ({ media: true, transfers: true, voice: false })")
assert dismissed == ["voice"], "going away on its own is not a dismissal"
h.eval(c, "available = ({ media: true, transfers: true, voice: true })")
assert is_open() == "voice", "it opens again for the next session"
c.setProperty("suspended", True)
assert is_open() == "" and dismissed == ["voice", "voice"], "another view taking the notch dismisses it"
c.setProperty("suspended", False)
h.eval(c, "available = ({ media: true, transfers: true, voice: false })")
assert is_open() == "" and not h.eval(c, "modal")
print("NotchPanelController: delays, crossing, switching, hold, suspension, availability, click mode and auto panels passed")
