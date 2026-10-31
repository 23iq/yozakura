"""The sentence bar module (modules/bar/modules/Sentence.qml) offscreen,
real bar: the line reads in order and in the UI language, empty fragments
hide, each fragment does its module's action (clock popup, overview,
network settings, do-not-disturb), a narrow bar drops the lowest ranked
fragments whole, a vertical bar turns the line (-90 on the left, 90 on the
right), and with the notch on the island keeps the track."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib import headless  # noqa: E402,F401
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from sentence_env import find, sentence_scene  # noqa: E402


def texts(h, win) -> list:
    line = find(win.contentItem(), "sentenceLine")
    return json.loads(h.eval(line, "JSON.stringify(fragments.filter((f, i) => keep[i]).map(f => f.text))"))


def click(win, name: str, button=Qt.MouseButton.LeftButton) -> None:
    item = find(win.contentItem(), name)
    assert item is not None and item.isVisible(), name
    p = item.mapToItem(None, item.width() / 2, item.height() / 2)
    QTest.mouseClick(win, button, Qt.KeyboardModifier.NoModifier, QPoint(round(p.x()), round(p.y())))
    QTest.qWait(300)


# Wide top bar, English: every fragment, in order, lead capitalized
env, win, svc = sentence_scene("sentence-test-wide", options={"fragments": ["clock", "window", "workspace", "battery",
                                                                           "network", "media", "notifications"],
                                                              "maxWidth": 1400}, width=1800)
h = env.h
said = texts(h, win)
assert said[0][0].isupper(), said
assert any("Aruarian Dance" in t for t in said), said
assert any(t.endswith("notifications") and t.startswith("3") for t in said), said
assert any(t.startswith("online") for t in said), said

# Nothing playing: the track hides, the rest stays
h.eval(svc, "MprisController.activePlayer = null")
QTest.qWait(300)
assert not any("Aruarian" in t for t in texts(h, win)), "no player: no track"

# Click: the clock opens its popup, the window the overview, the network
# its settings page; right click on the notifications toggles DND
click(win, "sentence:clock")
popup = find(win.contentItem(), "clockPopup")
assert popup is not None and h.eval(popup, "isOpen") is True, "clock: the calendar popup"
click(win, "sentence:clock")
click(win, "sentence:window")
assert "overview" in json.loads(h.eval(svc, "JSON.stringify(GlobalShortcuts.ran)")), "window: the overview"
click(win, "sentence:network")
assert h.eval(svc, "GlobalStates.settingsCategory") == "network", "network: its settings page"
click(win, "sentence:notifications", Qt.MouseButton.RightButton)
assert h.eval(svc, "Notifications.silent") is True, "right click: do not disturb"
win.close()

# Narrow bar in Russian: low priority fragments drop whole, the clock stays
env, win, svc = sentence_scene("sentence-test-narrow", width=700, lang="ru")
h = env.h
said = texts(h, win)
line = find(win.contentItem(), "sentenceLine")
assert h.eval(line, "shownCount") < h.eval(line, "fragments.length"), "narrow: something drops"
assert h.eval(line, "keep[0]") is True, "the clock ranks first and stays"
assert all("…" not in t or t.endswith("…") for t in said), "no mid-word cut"
win.close()

# Vertical bars turn the line along the edge
for edge, angle in (("left", -90), ("right", 90)):
    env, win, svc = sentence_scene(f"sentence-test-{edge}", edge=edge, width=1400, height=1000)
    stage = find(win.contentItem(), "sentenceStage")
    assert stage is not None and env.h.eval(stage, "rotation") == angle, f"{edge}: rotated {angle}"
    assert texts(env.h, win), f"{edge}: the line reads"
    win.close()

# Notch on: the island shows the track, the line leaves it out
env, win, svc = sentence_scene("sentence-test-notch", notch=True)
assert not any("Aruarian" in t for t in texts(env.h, win)), "notch on: the track stays in the island"
env, win, svc = sentence_scene("sentence-test-off")
assert find(win.contentItem(), "sentenceLine") is not None
# Off: taking the module out of the bar leaves no line, no popups, nothing
env.h.eval(svc, "(function(){ var p = JSON.parse(JSON.stringify(Config.bar.panels)); "
                "p[0].groups.start = ['launcher']; Config.bar.panels = p; })()")
QTest.qWait(400)
assert find(win.contentItem(), "sentenceLine") is None, "module removed: the sentence line is gone"
print("sentence bar: order, empty hides, actions, narrow drops, vertical turns, notch keeps the track")
env.h.exit(0)
