"""Code space task board, composer, plan, review and notch activity.

Real AiCenterPanel, TasksService and task components on the aiscene
(tests/lib/aiscene.py) with a scripted `tasks.*` IPC (BackendService stub:
`responses[method]`, `emit(kind, data)` for subscription events): board
grouping in the list and in columns, J/K/Enter, task creation (best-of-N,
plan first, `/template`), plan edit + Run, review accept (confirm, message),
a refused accept, discard with confirmation, tasks.open focus, the notch
activity and the history filter of task sessions.
"""
import json
import os
import sys
from pathlib import Path

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402,F401
from lib import aiscene  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer, Qt, QUrl  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlEngine, QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
PROJECT = "/home/user/src/yozakura"
app = QGuiApplication([])
root = aiscene.build("Sumi-e", "dark", (REPO / "tests/fixtures/aicenter-ai-stub.qml.in").read_text())
# Only the tasks provider of the activities module (the others need Pipewire & co).
(root / "qs/modules/services/activities/qmldir").write_text(
    "module qs.modules.services.activities\nActivityProvider 1.0 ActivityProvider.qml\nsingleton TasksActivity 1.0 TasksActivity.qml\n")
scene = root / "Tasks.qml"
scene.write_text("""import QtQuick
import qs.modules.services
import qs.modules.services.activities
import qs.modules.globals
import qs.modules.aicenter
Item {
    width: 1280; height: 800
    AiCenterPanel { id: panel; objectName: "panel"; anchors.fill: parent }
    function calls(m) { return JSON.stringify(BackendService.calls.filter(c => c.method === m).map(c => c.params)); }
    function emit(kind, json) { BackendService.emit(kind, JSON.parse(json)); }
    function respond(m, json) { const r = BackendService.responses; r[m] = JSON.parse(json); BackendService.responses = r; }
    function fail(m, text) { const r = BackendService.responses; r[m] = {__error: text}; BackendService.responses = r; }
    function svc() { return TasksService; }
    function activity() { return JSON.stringify(TasksActivity.activities); }
    function clickActivity() { TasksActivity.activate(TasksActivity.activities[0], Qt.LeftButton, "one"); }
    function history() { return JSON.stringify(Ai.agents.sessions.filter(s => !TasksService.sessionIds[s.id]).map(s => s.id)); }
}
""")


def task(tid, status, **extra):
    runs = extra.pop("runs", None)
    t = {"id": tid, "projectDir": PROJECT, "title": "Task " + tid, "prompt": "p", "mode": "run", "inPlace": False,
         "status": status, "plan": [], "planText": "", "baseBranch": "main", "error": "", "createdAt": 1000,
         "updatedAt": 1000, "startedAt": 0, "finishedAt": 0, "cost": {"inputTokens": 0, "outputTokens": 0, "costUsd": 0},
         "runs": runs if runs is not None else [{"index": 0, "agent": "claude", "status": status, "branch": "yoz/" + tid,
                                                  "worktree": "/wt/" + tid, "sessionId": "", "sessionIds": [], "attempts": 0,
                                                  "checks": [], "pending": [], "summary": "", "commitMessage": ""}]}
    t.update(extra)
    return t


TASKS = [
    task("run1", "running", startedAt=500),
    task("wait1", "waiting", runs=[{"index": 0, "agent": "codex", "status": "waiting", "branch": "yoz/wait1", "sessionId": "s1",
                                     "sessionIds": ["s1"], "pending": ["p1"], "checks": [], "attempts": 0}]),
    task("plan1", "awaiting_plan", mode="plan", plan=["Read the code", "Change it"]),
    task("rev1", "review", runs=[
        {"index": 0, "agent": "claude", "status": "review", "branch": "yoz/rev1", "attempts": 1, "summary": "Added hello.txt.",
         "commitMessage": "Add hello", "checks": [{"command": "make check", "status": "pass", "exitCode": 0, "durationMs": 1200, "outputTail": "ok"}],
         "changes": {"files": 1, "insertions": 1, "deletions": 0, "paths": ["hello.txt"]}},
        {"index": 1, "agent": "codex", "status": "review", "branch": "yoz/rev1-1", "attempts": 0, "summary": "Wrote hello.",
         "commitMessage": "hello", "checks": [], "changes": {"files": 2, "insertions": 3, "deletions": 1, "paths": ["a", "b"]}}]),
    task("q1", "queued", createdAt=3000),
    task("done1", "accepted", finishedAt=4000),
    task("elsewhere", "running", projectDir="/other"),
]

view = QQuickView()
view.engine().addImportPath(str(root))
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(1280, 800)
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
    item = item or top
    if item.objectName() == name:
        return item
    for child in item.childItems():
        hit = find(name, child)
        if hit is not None:
            return hit
    return None


def shown(name):
    obj = find(name)
    if obj is None:
        return False
    while obj is not None:
        if not obj.property("visible"):
            return False
        obj = obj.parentItem()
    return True


def find_all(name, item=None, out=None):
    out = [] if out is None else out
    item = item or top
    if item.objectName() == name:
        out.append(item)
    for child in item.childItems():
        find_all(name, child, out)
    return out


def visible_chain(obj):
    while obj is not None:
        if not obj.property("visible"):
            return False
        obj = obj.parentItem()
    return True


def click(name):
    hits = [o for o in find_all(name) if visible_chain(o)]
    assert hits, name
    obj = hits[0]
    point = obj.mapToScene(obj.boundingRect().center())
    QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, point.toPoint())
    pump()


def key(k, target=None):
    QTest.keyClick(view, k)
    pump()


def calls(method):
    return json.loads(ev(top, f"calls('{method}')"))


def emit(kind, data):
    ev(top, f"emit('{kind}', {json.dumps(json.dumps(data))})")
    pump()


def respond(method, data):
    ev(top, f"respond('{method}', {json.dumps(json.dumps(data))})")


svc = ev(top, "svc()")
panel = find("panel")
respond("tasks.templates.list", [{"id": "review", "name": "Review", "description": "Review the diff", "mode": "run"},
                                 {"id": "tests", "name": "Tests", "description": "Add tests", "mode": "run"}])
respond("tasks.project.get", {"dir": PROJECT, "checkCommand": None, "maxAttempts": 2, "mergeMode": "squash", "checkTimeout": 600,
                              "effectiveCheck": "make check", "suggestedCheck": "make check", "isGit": True, "instructions": ""})
respond("tasks.git", {"dir": PROJECT, "isRepo": True, "branch": "main", "head": "abc1234", "ahead": 2, "behind": 0, "changed": 3,
                      "staged": 1, "unstaged": 1, "untracked": 1, "conflicts": 0})
respond("tasks.configure", {"maxParallel": 2})
ev(svc, "refreshAll('%s')" % PROJECT)

# Code space without an agent session: the task workspace.
ev(top, "Ai.setSpace('code')")
ev(top, "Ai.agents.activeId = ''")
pump(200)
emit("tasks.list", TASKS)
assert ev(svc, "ready") and ev(svc, "tasks.length") == len(TASKS)
assert calls("tasks.configure"), "settings are pushed after the first list"
assert shown("taskWorkspace") and shown("taskOptions") and not shown("composerStatus")

# Project bar: git summary from tasks.git, missing AGENTS.md offers an agent task.
ev(panel, "true")
pump()
assert ev(find("gitBranch"), "text") == "main"
assert "3" in ev(find("gitChanged"), "text")
assert shown("projectSettings")
ev(find("projectSettings"), "set({maxAttempts: 3})")
assert calls("tasks.project.set")[-1] == {"dir": PROJECT, "maxAttempts": 3}

# Compact: sectioned list, attention first, other projects filtered out, done folded.
ws = find("taskWorkspace")
sections = [s["id"] for s in json.loads(ev(ws, "JSON.stringify(board.sections.map(s => ({id: s.id})))"))]
assert sections == ["waiting", "running", "review", "queued", "done"], sections
assert json.loads(ev(ws, "JSON.stringify(ids)")) == ["wait1", "plan1", "run1", "rev1", "q1"]
assert shown("boardList") and not shown("boardColumns")
assert shown("taskCard_wait1") and not shown("taskCard_done1") and find("taskCard_elsewhere") is None

# Wide: columns.
ev(top, "GlobalStates.assistantWide = true")
pump(200)
assert shown("boardColumns") and not shown("boardList")

# Keyboard: J moves the cursor, Enter opens; Esc goes back.
ev(ws, "forceActiveFocus()")
key(Qt.Key_J)
assert ev(ws, "cursorId") == "wait1"
key(Qt.Key_J)
key(Qt.Key_Return)
assert ev(svc, "selectedId") == "plan1"
assert shown("taskDetail") and shown("boardList"), "wide: list + detail side by side"
# Plan review: edit, add, reorder, Run with the edited steps.
assert shown("planEditor")
ed = find("planEditor")
ev(ed, "edit(TaskModel.planSet(steps, 0, 'Read the module'))")
click("planAddStep")
assert ev(ed, "steps.length") == 3
ev(ed, "edit(TaskModel.planSet(steps, 2, 'Run tests'))")
ev(ed, "edit(TaskModel.planMove(steps, 2, 0))")
click("planRun")
run = calls("tasks.run")[-1]
assert run == {"id": "plan1", "steps": ["Run tests", "Read the module", "Change it"]}, run

# Review: best-of-N side by side, accept asks first, message is sent.
ev(svc, "select('rev1', -1)")
pump(200)
assert shown("reviewView") and shown("runChoice")
assert ev(find("commitMessage"), "text") == "Add hello"
click("runCard_1")
assert ev(svc, "selectedRun") == 1
pump()
assert ev(find("commitMessage"), "text") == "hello"
ev(find("commitMessage"), "text = 'feat: hello'")
respond("tasks.accept", task("rev1", "accepted"))
click("reviewAccept")
assert shown("confirmAccept") and not calls("tasks.accept")
click("confirmOk")
accept = calls("tasks.accept")[-1]
assert accept == {"id": "rev1", "run": 1, "message": "feat: hello"}, accept
emit("tasks.updated", TASKS[3])  # back to review for the refusal case
ev(svc, "select('rev1', 0)")
pump()
ev(top, "fail('tasks.accept', 'the project has uncommitted changes in files this task changes: hello.txt (commit or stash them first)')")
ev(find("reviewView"), "doAccept()")
pump()
assert shown("reviewError")
assert "uncommitted" in ev(find("reviewView"), "error")

# Request changes -> follow-up of the selected run.
ev(find("requestChanges"), "text = 'Also add a README line'")
click("requestChangesSend")
assert calls("tasks.followup")[-1] == {"id": "rev1", "run": 0, "text": "Also add a README line"}

# D discards after a confirmation.
ev(ws, "forceActiveFocus()")
key(Qt.Key_D)
pump()
assert shown("detailConfirmDiscard") and not calls("tasks.discard")
click("confirmOk")
assert calls("tasks.discard")[-1] == {"id": "rev1"}

# Waiting task: banner and live transcript of its session.
ev(svc, "select('wait1', -1)")
pump(200)
assert shown("waitingBanner")

# Create: best-of-N with plan first.
ev(svc, "select('', -1)")
ev(top, "GlobalStates.assistantWide = false")
pump(200)
respond("tasks.create", task("new1", "queued"))
click("taskAgent_codex")
click("taskPlanFirst")
composer = find("workspaceComposer")
ev(composer, "text = 'Add a hello file'")
ev(composer, "submit()")
pump()
create = calls("tasks.create")[-1]
assert create == {"dir": PROJECT, "prompt": "Add a hello file", "agents": ["claude", "codex"], "mode": "plan"}, create
assert ev(composer, "text") == "", "the composer clears after a task is created"
assert ev(svc, "selectedId") == "new1", "the new task opens"
# Template: `/review` is offered and becomes the template param.
ev(svc, "select('', -1)")
click("taskAgent_codex")
click("taskPlanFirst")
ev(composer, "text = '/re'")
pump()
assert any(m["cmd"] == "/review" for m in json.loads(ev(composer, "JSON.stringify(slashMatches)")))
ev(composer, "text = '/review the auth module'")
ev(composer, "submit()")
pump()
create = calls("tasks.create")[-1]
assert create["template"] == "review" and create["prompt"] == "the auth module" and create["agent"] == "claude", create
# Empty input is refused and keeps the composer as is.
before = len(calls("tasks.create"))
ev(composer, "text = '   '")
assert ev(find("taskOptions"), "submit('   ', [])") is False
assert len(calls("tasks.create")) == before

# Esc in an empty composer moves to the board (keyboard navigation), Esc there closes the bar.
ev(composer, "text = ''")
ev(svc, "select('', -1)")
pump()
ev(composer, "focusInput()")
ev(composer, "escapePressed()")
pump()
assert ev(find("taskWorkspace"), "activeFocus"), "Esc hands the keyboard to the board"
key(Qt.Key_Escape)
assert not ev(top, "GlobalStates.assistantVisible")
ev(top, "GlobalStates.assistantVisible = true")

# Missing AGENTS.md: "Create with agent" starts an instructions task.
ev(find("projectInstructions"), "clicked()")
pump()
ev(find("projectBar"), "createInstructions()")
pump()
assert calls("tasks.create")[-1]["template"] == "instructions"

# Notch activity: "Codex is waiting", click focuses the task.
emit("tasks.activity", {"running": 1, "waiting": 1, "review": 1, "queued": 1, "failed": 0, "limited": 0, "headline": "waiting",
                        "agent": "Codex", "taskId": "wait1", "items": [{"id": "wait1", "title": "Task wait1", "status": "waiting"}]})
act = json.loads(ev(top, "activity()"))
assert len(act) == 1 and act[0]["label"] == "Codex is waiting" and act[0]["indicator"] == "dot", act
ev(svc, "select('', -1)")
ev(top, "GlobalStates.assistantVisible = false")
ev(top, "clickActivity()")
pump()
assert ev(svc, "selectedId") == "wait1" and ev(top, "GlobalStates.assistantVisible")
emit("tasks.activity", {"headline": "running", "running": 3, "items": []})
act = json.loads(ev(top, "activity()"))
assert act[0]["label"] == "3 tasks running" and act[0]["indicator"] == "ring", act
emit("tasks.activity", {"headline": "idle", "items": []})
assert json.loads(ev(top, "activity()")) == []

# tasks.open (notification "Open"): Code space, task selected.
ev(top, "Ai.setSpace('assistant')")
emit("tasks.open", {"id": "q1", "run": 0})
assert ev(top, "GlobalStates.aiSpace") == "code" and ev(svc, "selectedId") == "q1"

# Task sessions stay out of the Code history.
assert json.loads(ev(top, "history()")) == [], "s1 belongs to wait1"
emit("tasks.removed", {"id": "wait1"})
assert json.loads(ev(top, "history()")) == ["s1"]

print("ai-tasks-ui: ok")
