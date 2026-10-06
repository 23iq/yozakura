"""Code project picker in the AI bar (real AiCenterPanel, ProjectBar,
FolderPicker, TasksService on the aiscene; `fs.*` IPC scripted).

Project ▾ -> Open folder… opens the in-bar sheet: recent folders and the
discovered repositories (fs.repos), a typed path browses (fs.list) with
git repositories marked, Enter chooses the best match -> Ai.chooseProject,
the project bar shows it and TasksService refreshes that project. Also the
model shown before the first message (task options, Assistant empty state).
"""
import json
import os
import sys
from pathlib import Path

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402,F401
from lib import aiscene  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer, Qt, QUrl, qInstallMessageHandler  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlEngine, QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
app = QGuiApplication([])
errors = []
qInstallMessageHandler(lambda m, c, s: errors.append(s) if ("aicenter" in s or "TypeError" in s or "ReferenceError" in s) and "Binding loop" not in s and "recursive rearrange" not in s else None)
root = aiscene.build("Sumi-e", "dark", (REPO / "tests/fixtures/aicenter-ai-stub.qml.in").read_text())
(root / "qs/modules/services/activities/qmldir").write_text(
    "module qs.modules.services.activities\nActivityProvider 1.0 ActivityProvider.qml\nsingleton TasksActivity 1.0 TasksActivity.qml\n")
scene = root / "Picker.qml"
scene.write_text("""import QtQuick
import qs.modules.services
import qs.modules.globals
import qs.modules.aicenter
Item {
    width: 380; height: 720
    AiCenterPanel { id: panel; objectName: "panel"; anchors.fill: parent }
    function calls(m) { return JSON.stringify(BackendService.calls.filter(c => c.method === m).map(c => c.params)); }
    function setup() {
        const r = BackendService.responses;
        r["fs.repos"] = {repos: [{path: "/home/user/src/quickshell", name: "quickshell"}, {path: "/home/user/work/api", name: "api"}]};
        r["fs.list"] = p => ({dir: p.dir, parent: "/home", entries: p.dir === "/home/user" ? [
            {name: "src", path: "/home/user/src", git: false, hidden: false},
            {name: "yozakura", path: "/home/user/yozakura", git: true, hidden: false},
            {name: ".config", path: "/home/user/.config", git: false, hidden: true}] : []});
        BackendService.responses = r;
    }
}
""")
view = QQuickView()
view.engine().addImportPath(str(root))
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(380, 720)
view.setSource(QUrl.fromLocalFile(str(scene)))
assert view.status() == QQuickView.Ready, view.errors()
view.show()
top = view.rootObject()


def pump(ms=120):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


def ev(target, expr):
    e = QQmlExpression(QQmlEngine.contextForObject(target) or view.engine().rootContext(), target, expr)
    value = e.evaluate()
    assert not e.hasError(), f"{expr}: {e.error().toString()}"
    return value[0] if isinstance(value, tuple) else value


def find(name, item=None):
    item = item or view.contentItem()  # popups live in the window overlay
    if item.objectName() == name:
        return item
    for child in item.childItems():
        hit = find(name, child)
        if hit is not None:
            return hit
    return None


def shown(name):
    obj = find(name)
    while obj is not None:
        if not obj.property("visible"):
            return False
        obj = obj.parentItem()
    return find(name) is not None


def click(name):
    obj = find(name)
    assert obj is not None and shown(name), name
    QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, obj.mapToScene(obj.boundingRect().center()).toPoint())
    pump()


def calls(method):
    return json.loads(ev(top, f"calls('{method}')"))


ev(top, "setup()")
# Assistant empty state names the model a first message will use.
pump(200)
assert shown("usingModel") and "Claude Sonnet 4.5" in ev(find("usingModelText"), "text"), ev(find("usingModelText"), "text")

ev(top, "Ai.setSpace('code')")
ev(top, "Ai.agents.activeId = ''")
pump(200)
# Task options show the concrete default model / effort before the first task.
assert ev(find("taskModel"), "label") == "Opus 5.5"
assert ev(find("taskEffort"), "label") == "high"

# Project ▾ -> Open folder… opens the in-bar picker (no zenity).
click("projectButton")
click("projectOpenFolder")
pump(200)
assert shown("folderPicker"), "picker sheet visible"
assert ev(find("panel"), "overlay") == "folder"
assert calls("fs.repos"), "repositories requested"
picker = find("folderPicker")
rows = json.loads(ev(picker, "JSON.stringify(rows)"))
assert [r.get("label") or r["name"] for r in rows] == ["recent", "yozakura", "notes", "repos", "quickshell", "api"], rows
# Search filters recent folders and repositories.
field = find("folderField")
field.setProperty("text", "qui")
pump()
assert [r["name"] for r in json.loads(ev(picker, "JSON.stringify(rows)")) if r["type"] != "header"] == ["quickshell"]
assert ev(picker, "target") == "/home/user/src/quickshell", "a typed name selects its best match"
# A path browses the folder; git repositories are marked, dot folders hidden.
QTest.mouseMove(view, find("folderField").mapToScene(find("folderField").boundingRect().center()).toPoint())
field.setProperty("text", "~/")
pump()
assert calls("fs.list")[-1] == {"dir": "/home/user"}
rows = [r for r in json.loads(ev(picker, "JSON.stringify(rows)")) if r["type"] == "dir"]
assert [(r["name"], r["git"]) for r in rows] == [("src", False), ("yozakura", True)], rows
assert ev(picker, "target") == "/home/user", "nothing typed after / -> the browsed folder"
click("folderHidden")
assert len([r for r in json.loads(ev(picker, "JSON.stringify(rows)")) if r["type"] == "dir"]) == 3
# A typed folder that does not exist is refused with a message.
ev(picker, "choose('/home/user/nope')")
assert shown("folderPicker") and "nope" in ev(find("folderError"), "text")
assert json.loads(ev(top, "JSON.stringify(Ai.chosenProjects)")) == []
# Keyboard: type, Enter chooses the best match.
field.forceActiveFocus()
field.setProperty("text", "~/yo")
pump()
QTest.keyClick(view, Qt.Key_Return)
pump(200)
assert json.loads(ev(top, "JSON.stringify(Ai.chosenProjects)")) == ["/home/user/yozakura"]
assert not shown("folderPicker") and ev(find("panel"), "overlay") == ""
assert ev(find("projectBar"), "project") == "/home/user/yozakura", "project bar shows the choice"
assert {"dir": "/home/user/yozakura"} in calls("tasks.project.get"), "tasks refreshed for the new project"
assert ev(find("taskWorkspace"), "project") == "/home/user/yozakura", "the board follows the project"

# Tab browses into the selection; Esc closes without choosing.
ev(find("panel"), "openFolderPicker()")
pump()
field.forceActiveFocus()
field.setProperty("text", "~/s")
pump()
QTest.keyClick(view, Qt.Key_Tab)
pump()
assert ev(field, "text") == "~/src/"
QTest.keyClick(view, Qt.Key_Escape)
pump()
assert not shown("folderPicker")
assert len(json.loads(ev(top, "JSON.stringify(Ai.chosenProjects)"))) == 1

# Session settings: Browse opens the same picker.
ev(find("panel"), "setOverlay('settings')")
pump()
click("settingsBrowse")
assert shown("folderPicker")

bad = [e for e in errors if "aiscene" in e or "TypeError" in e or "ReferenceError" in e]
assert not bad, bad
print("ai-folder-picker: ok")
