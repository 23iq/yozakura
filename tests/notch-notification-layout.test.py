"""Notifications in the notch (notifications.presentation "notch"), offscreen
with the real island (IslandEnv): both notchStyle values keep their geometry
between rest and hover (the art and the summary do not move or resize; the
dismiss button only fades in, in its reserved place), the actions show only
while hovered (the first one is the primary action), the card sits at the
notch panels' inset (Look.surfacePadding) and the caption counts the popups.

Regression: the card grew its icon and re-flowed its text on hover, spread
bare action labels over the full width and showed no app name or time."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib import headless  # noqa: E402,F401
from island_env import IslandEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from lib.waits import wait_until  # noqa: E402

env = IslandEnv("notch-notification-layout", notch={"style": "attached", "expandOn": "click"}, theme={"language": "ink"})
h = env.h


def geometry(win, name: str) -> tuple:
    item = h.find(win, name)
    text = h.eval(item, "(function(){ var p = mapToItem(null, 0, 0); return [p.x, p.y, width, height].join(','); })()")
    return tuple(round(float(v)) for v in text.split(","))


def scene(style: str, kind: str = ""):
    win = env.scene()
    h.eval(win, "seed()")
    h.eval(win, f"Config.notifications.notchStyle = '{style}'")
    h.eval(win, f"notifyKind('{kind}')" if kind else "notify(true)")
    QTest.qWait(400)
    return win


def hover(win, on: bool) -> None:
    h.eval(h.find(win, "islandNotifications"), f"hovered = {'true' if on else 'false'}")
    QTest.qWait(400)


def actions(win) -> list:
    """The shown action chips as (primary, x, width)."""
    row = h.find(win, "toastActions")
    text = h.eval(row, "visible ? children.filter(c => c.primary !== undefined && c.visible)"
                       ".map(c => [c.primary, c.x, c.width].join(':')).join(';') : ''")
    return [(p == "true", float(x), float(w)) for p, x, w in (c.split(":") for c in text.split(";") if c)]


# Card: stable art and summary, dismiss and actions on hover only
win = scene("card")
notes = h.find(win, "islandNotifications")
group = h.find(win, "islandNotificationGroup")
assert h.eval(group, "x") == h.eval(notes, "padding"), "the card sits at the panels' side inset"
art_rest = geometry(win, "toastArt")
text_rest = h.eval(h.find(win, "notchCardContent"), "mapToItem(null, 0, 0).y")
dismiss = h.find(win, "notificationDismiss")
assert h.eval(dismiss, "opacity") == 0 and not h.eval(dismiss, "enabled"), "no dismiss button at rest"
assert actions(win) == [], "no actions at rest"
caption = h.eval(h.find(win, "notchCardContent"), "notification.appName")
assert caption == "Telegram"
hover(win, True)
assert geometry(win, "toastArt") == art_rest, f"the art keeps its place and size on hover: {art_rest} -> {geometry(win, 'toastArt')}"
assert h.eval(h.find(win, "notchCardContent"), "mapToItem(null, 0, 0).y") == text_rest
wait_until(lambda: h.eval(dismiss, "opacity") == 1)
shown = actions(win)
assert len(shown) == 2, "both actions show on hover"
assert shown[0][0] and not shown[1][0], "only the first action is primary"
assert shown[1][1] >= shown[0][1] + shown[0][2], "actions sit side by side at their own width"
assert shown[0][2] < h.eval(group, "width") / 2, "actions are not stretched over the card"
win.close()

# Compact: one line at rest, unfolds below it on hover
win = scene("compact")
line_rest = geometry(win, "compactLine")
art_rest = geometry(win, "compactArt")
details = h.find(win, "compactDetails")
assert not h.eval(details, "visible"), "the body and actions are folded at rest"
hover(win, True)
assert geometry(win, "compactLine") == line_rest, "the line keeps its place on hover"
assert geometry(win, "compactArt") == art_rest, "the art keeps its place and size on hover"
assert h.eval(details, "visible") and h.eval(details, "y") >= line_rest[3], "the details open under the line"
assert len(actions(win)) == 2 and actions(win)[0][0]
win.close()

# No actions, no body: hover only shows the dismiss button
win = scene("compact", "plain")
height_rest = h.eval(h.find(win, "islandNotifications"), "implicitHeight")
hover(win, True)
assert h.eval(h.find(win, "islandNotifications"), "implicitHeight") == height_rest, "nothing to unfold, no growth"
win.close()

# Several popups: the caption shows the place among them
win = scene("card", "multi")
text = h.eval(h.find(win, "notchCardContent"), "position")
assert text == "1/3", text
win.close()

print("notch notifications: stable rest/hover geometry, hover-only dismiss and actions, panel inset, popup position")
h.exit(0)
