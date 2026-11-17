"""AI transcript scroll memory in a long conversation (real AiCenterPanel,
services stubbed by tests/lib/aiscene.py, offscreen).

- Scrolled to the very end (positionViewAtEnd stops short of the bottom
  margin, where atYEnd is still false) the view keeps following the end.
- Scrolled up and rebuilt (the sidebar closed and opened again), it shows
  the same row at the top: the position is kept as a row, not as a pixel
  offset that a rebuilt list (row heights only estimated) would map onto
  much older messages.
- Thinking rows shown / hidden while scrolled up (the transcript is rebuilt,
  its row indices move): the same message stays at the top.
- Rows that arrive only after the transcript opened (an agent session still
  loading): the remembered row is waited for, not dropped for the end.
"""
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402

headless.ensure(gl=True)
from PySide6.QtCore import QMetaObject, QObject, QUrl  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

from lib import aiscene, waits  # noqa: E402
from lib.waits import pump  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
app = QGuiApplication([])
waits.keep_deferred_deletes()

# the scene of the AI center UI test (an AiCenterPanel in a Loader that
# `kind` switches off and on)
SCENE = re.search(r'SCENE = """(.*?)"""', (REPO / "tests/ai-center-ui.test.py").read_text(), re.S).group(1)

CHAT = []
for i in range(60):
    CHAT.append({"role": "user", "content": f"Question {i}: " + "why does this do that " * (1 + i % 4)})
    think = f"Thinking about {i}. " * (2 + i % 3)
    body = f"Answer {i}. " + "A long sentence of the explanation that wraps across the line. " * (3 + i % 7)
    if i % 3 == 0:
        body += "\n\n```python\n" + "\n".join(f"x{j} = {j}" for j in range(8 + i % 10)) + "\n```\n"
    CHAT.append({"role": "assistant", "model": "M", "content": body, "thinking": think})

root = aiscene.build("Yozakura Night", "dark", (REPO / "tests/fixtures/aicenter-ai-stub.qml.in").read_text(), "")
app_dir = root / "app"
app_dir.mkdir()
(app_dir / "Scene.qml").write_text(SCENE % {"W": 1440, "H": 860, "SEL": ""})
(app_dir / "SelectionMenu.qml").write_text("import QtQuick\nItem {}\n")
(app_dir / "Settings.qml").write_text("import QtQuick\nItem {}\n")

view = QQuickView()
view.engine().addImportPath(str(root))
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(1440, 860)
view.setSource(QUrl.fromLocalFile(str(app_dir / "Scene.qml")))
assert view.status() == QQuickView.Ready, [e.toString() for e in view.errors()]


def evaluate(obj, expr):
    e = QQmlExpression(view.engine().contextForObject(obj) or view.engine().rootContext(), obj, expr)
    value = e.evaluate()
    value = value[0] if isinstance(value, tuple) else value
    assert not e.hasError(), f"{expr}: {e.error().toString()}"
    return value


def chat_list():
    """The live transcript list (closed panels are kept, not deleted)."""
    lists = [o for o in view.rootObject().findChildren(QObject, "workspaceChatList") if o.property("visible")]
    assert lists, "the transcript is shown"
    return lists[-1]


def top_row():
    return evaluate(chat_list(), "indexAt(width / 2, contentY + topMargin)")


evaluate(view.rootObject(), "setup(" + json.dumps({"chat": CHAT, "quick": [], "agent": []}) + ")")
view.show()
pump(1500)

lst = chat_list()
ROWS = len(CHAT) + len(CHAT) // 2  # a thinking row per reply
assert lst.property("count") == ROWS, lst.property("count")
assert evaluate(lst, "indexAt(width / 2, contentY + height - Space.xl)") == ROWS - 1, "opens at the end"

# the user scrolls to the very end: the view still follows it
evaluate(lst, "positionViewAtEnd()")
pump(100)
QMetaObject.invokeMethod(lst, "movementEnded")
pump(100)
assert evaluate(lst, "stick"), "at the end the view keeps following new messages"
assert evaluate(lst, "JSON.stringify(parent.scrollPosition)") == "-1"

# the user scrolls up to row 40, the sidebar closes and opens again
evaluate(lst, "stick = false")
# (a ListView builds its cache rows over a few frames, the rows above
# shifting as they get their real heights: position until it holds)
last = None
for _ in range(20):
    evaluate(lst, "positionViewAtIndex(40, ListView.Beginning)")
    pump(300)
    now = (top_row(), lst.property("originY"))
    if now[0] == 40 and now == last:
        break
    last = now
assert top_row() == 40, top_row()
QMetaObject.invokeMethod(lst, "movementEnded")
pump(100)
# (the list then builds its cache rows above, which may nudge the view)
saved = json.loads(evaluate(lst, "JSON.stringify(parent.scrollPosition)"))
assert isinstance(saved, dict) and saved["index"] == 40, saved
assert not evaluate(lst, "stick")
evaluate(view.rootObject(), "kind = 'settings'")
pump(300)
evaluate(view.rootObject(), "kind = 'chat'")
pump(2000)
assert chat_list() is not lst, "the transcript was rebuilt"
assert top_row() == 40, f"the rebuilt transcript shows row {top_row()} at the top, not the remembered 40"



def top_key():
    lst = chat_list()
    return evaluate(lst, "(function(i) { return i < 0 ? '' : parent.model.rows.get(i).key })(indexAt(width / 2, contentY + topMargin))")


def scroll_to(index):
    lst = chat_list()
    evaluate(lst, "stick = false")
    last = None
    for _ in range(20):
        evaluate(lst, f"positionViewAtIndex({index}, ListView.Beginning)")
        pump(300)
        now = (top_row(), lst.property("originY"))
        if now[0] == index and now == last:
            break
        last = now
    QMetaObject.invokeMethod(lst, "movementEnded")
    pump(100)


# thinking hidden while scrolled up: the rows are rebuilt and every index
# above moves, the message at the top stays
reply = evaluate(chat_list(), "(function() { for (let i = 61; i < count; i++) if (parent.model.rows.get(i).key.endsWith(':text')) return i; return -1 })()")
scroll_to(reply)
key = top_key()
assert key.endswith(":text"), key  # a reply, which stays when thinking hides
lst = chat_list()
evaluate(lst, "parent.model.showThinking = false")
pump(1200)
assert top_key() == key, f"after hiding thinking the top row is {top_key()}, not {key}"
evaluate(lst, "parent.model.showThinking = true")
pump(1200)
assert top_key() == key, f"after showing thinking the top row is {top_key()}, not {key}"

# the rows arrive only after the transcript opened (a session still
# loading): the remembered row is waited for
scroll_to(61)
# (what was saved when the movement ended: the list then builds its cache
# rows above, which may nudge the view)
key = json.loads(evaluate(chat_list(), "JSON.stringify(parent.scrollPosition)"))["key"]
evaluate(view.rootObject(), "kind = 'settings'")
pump(300)
evaluate(view.rootObject(), "Ai.chat.rows.clear()")
evaluate(view.rootObject(), "kind = 'chat'")
pump(100)
for start in range(0, len(CHAT), 30):  # in batches, a frame apart
    evaluate(view.rootObject(), "setup(" + json.dumps({"chat": CHAT[start:start + 30], "quick": [], "agent": []}) + ")")
    pump(60)
pump(1500)
assert chat_list().property("count") == ROWS
assert top_key() == key, f"after loading the top row is {top_key()}, not the remembered {key}"

print("ai-transcript-scroll: ok")
sys.stdout.flush()
os._exit(0)
