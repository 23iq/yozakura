"""TmuxTab offscreen: session list, filtering, preview parsing and keyboard flow.

Loads the real tab (and its sibling components) on SettingsEnv with a fake
`tmux` behind Quickshell.Io.Process: every command is recorded and answered
from a fixture, so the test checks the exact tmux invocations too.
"""
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from qmlharness import REPO  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402
from PySide6.QtCore import QCoreApplication, QEvent, Qt  # noqa: E402
from PySide6.QtGui import QKeyEvent  # noqa: E402

env = SettingsEnv("tmux-tab")
h = env.h

h.module("tmuxfixture", {"TmuxFixture": """pragma Singleton
QtObject {
    property var log: []
    property var sessions: ["main", "work"]
    function respond(cmd) {
        log = log.concat([cmd.join(" ")]);
        const sub = cmd[1];
        if (sub === "list-sessions")
            return { code: 0, text: sessions.join("\\n") + "\\n" };
        if (sub === "list-windows")
            return { code: 0, text: "0:zsh:0\\n1:nvim:1\\n" };
        if (sub === "list-panes")
            return { code: 0, text: "0:80:24:0:0:1:nvim\\n1:79:24:0:81:0:zsh\\n" };
        if (sub === "rename-session") {
            sessions = sessions.map(s => s === cmd[3] ? cmd[4] : s);
            return { code: 0, text: "" };
        }
        if (sub === "kill-session") {
            sessions = sessions.filter(s => s !== cmd[3]);
            return { code: 0, text: "" };
        }
        return { code: 0, text: "" };
    }
}"""})
h.module("Quickshell.Io", {
    "Process": """import QtQuick
import tmuxfixture
QtObject {
    id: proc
    property var command: []
    property bool running: false
    property var stdout
    property var stderr
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: if (running) Qt.callLater(proc.run)
    function run() {
        const r = TmuxFixture.respond(command);
        if (stdout) { stdout.text = r.text; stdout.streamFinished(); }
        running = false;
        exited(r.code, 0);
    }
}""",
    "StdioCollector": "QtObject { property string text: ''; property bool waitForEnd: false; signal streamFinished() }",
})
h.module("qs.modules.services", {
    "TerminalService": "pragma Singleton\nQtObject { property var ran: []; function execDetached(c) { ran = ran.concat([c]); } }",
    "Visibilities": "pragma Singleton\nQtObject { property string module: 'dashboard'; "
                    "function setActiveModule(m) { module = m; } }",
})

tmux_dir = env.root / "qs/modules/widgets/dashboard/tmux"
shutil.copytree(REPO / "modules/widgets/dashboard/tmux", tmux_dir, dirs_exist_ok=True)
env._qmldir(tmux_dir, "qs.modules.widgets.dashboard.tmux")
root = env.load('import QtQuick\nimport tmuxfixture\nimport qs.modules.widgets.dashboard.tmux\nItem { property QtObject fx: TmuxFixture; width: 900; height: 420; TmuxTab { objectName: "tab"; '
                'anchors.fill: parent; leftPanelWidth: 400 } }')
tab = h.find(root, "tab")
# An object declared inside TmuxTab.qml: evaluates with the tab's own ids.
inner = next(c for c in tab.children() if c.metaObject().className().startswith("QQuickMouseArea"))


def pump(n=20):
    for _ in range(n):
        QCoreApplication.processEvents()


def ev(expr):
    return h.eval(inner, expr)


def js(expr):
    return json.loads(ev("JSON.stringify(" + expr + ")"))


def key(k):
    for t in (QEvent.KeyPress, QEvent.KeyRelease):
        QCoreApplication.sendEvent(tab, QKeyEvent(t, k, Qt.NoModifier))
    pump()


ok = True


def check(name, cond, detail=""):
    global ok
    ok &= bool(cond)
    print(("PASS " if cond else "FAIL ") + name + ("  " + str(detail) if detail else ""))


pump()
log = json.loads(h.eval(root, "JSON.stringify(fx.log)"))
check("lists sessions on load", "tmux list-sessions -F #{session_name}" in log, log)
names = [s["name"] for s in js("root.filteredSessions")]
check("create button + sessions", names == ["Create new session", "main", "work"], names)
check("model mirrors the list", ev("sessionsModel.count") == 3 and ev("resultsList.count") == 3)
check("nothing selected initially", ev("root.selectedIndex") == -1)

ev("root.searchText = 'wo'")
pump()
fs = js("root.filteredSessions")
check("search filters and offers a named create", [s["name"] for s in fs] == ['Create session "wo"', "work"]
      and fs[0]["isCreateSpecificButton"] and fs[0]["sessionNameToCreate"] == "wo", fs)
check("search selects the first row", ev("root.selectedIndex") == 0)
ev("root.searchText = 'work'")
pump()
fs = js("root.filteredSessions")
check("exact match keeps the generic create", fs[0]["isCreateButton"] and [s["name"] for s in fs][1:] == ["work"], fs)
ev("root.clearSearch()")
pump()

ev("searchInput.downPressed()")
ev("searchInput.downPressed()")
pump()
check("down arrow moves the selection", ev("root.selectedIndex") == 1 and ev("resultsList.currentIndex") == 1)
log = json.loads(h.eval(root, "JSON.stringify(fx.log)"))
check("selection loads windows and panes",
      "tmux list-windows -t main -F #{window_index}:#{window_name}:#{window_active}" in log
      and any(c.startswith("tmux list-panes -t main -F") for c in log), log[-2:])
wins = js("root.sessionWindows")
check("windows parsed", wins == [{"index": "0", "name": "zsh", "active": False},
                                 {"index": "1", "name": "nvim", "active": True}], wins)
panes = js("root.sessionPanes")
check("panes parsed with layout totals", len(panes) == 2 and panes[1]["left"] == 81 and panes[0]["active"]
      and panes[0]["totalWidth"] == 160 and panes[0]["totalHeight"] == 24 and not ev("root.loadingSessionInfo"), panes)

pump()
rows = ev("resultsList.contentItem.children.filter(c => c.sessionData !== undefined).length")
check("one row item per session", rows == 3, rows)
check("rendered texts", ev("resultsList.itemAtIndex(1).sessionData.name") == "main")
check("rows are kit ListRows, the cursor row selected",
      ev("resultsList.itemAtIndex(1).children[0].title") == "main"
      and ev("resultsList.itemAtIndex(1).children[0].selected")
      and not ev("resultsList.itemAtIndex(2).children[0].selected"))
# Pane boxes and window chips: items carrying a pane/window modelData + hovered.
chips = h.eval(root, "(function f(i) { var n = (i.modelData !== undefined && i.hovered !== undefined"
                     " && i.modelData && i.modelData.index !== undefined) ? 1 : 0;"
                     " for (var k = 0; k < i.children.length; k++) n += f(i.children[k]); return n; })(children[0])")
check("pane boxes and window chips rendered", chips == 4, chips)

ev("root.switchToWindow('main', '1')")
ev("root.focusPane('main', '1')")
pump()
log = json.loads(h.eval(root, "JSON.stringify(fx.log)"))
check("window/pane commands", "tmux select-window -t main:1" in log and "tmux select-pane -t main.1" in log)

ev("searchInput.shiftAccepted()")
check("shift+enter expands the options", ev("root.expandedItemIndex") == 1 and ev("root.keyboardNavigation"))
ev("searchInput.downPressed()")
check("down navigates options", ev("root.selectedOptionIndex") == 1)
pump()
opts = json.loads(h.eval(root, "JSON.stringify((function f(i) { var r = []; if (i.shown === false) return r; if (i.title !== undefined && i.highlighted !== undefined"
                    " && i.modelData && i.modelData.icon !== undefined) r.push(i.title + (i.highlighted ? '*' : ''));"
                    " for (var k = 0; k < i.children.length; k++) r = r.concat(f(i.children[k])); return r; })(children[0]))"))
check("options are compact rows, the keyboard one highlighted",
      opts == ["Open", "Rename*", "Quit"], opts)
ev("searchInput.accepted()")
pump()
check("rename option enters rename mode", ev("root.renameMode") and ev("root.sessionToRename") == "main"
      and ev("root.expandedItemIndex") == -1)
ev("root.newSessionName = 'dev'")
key(Qt.Key_Return)
pump(40)
log = json.loads(h.eval(root, "JSON.stringify(fx.log)"))
check("enter confirms the rename", "tmux rename-session -t main dev" in log, log[-3:])
names = [s["name"] for s in js("root.filteredSessions")]
check("renamed session is listed and selected", names == ["Create new session", "dev", "work"]
      and ev("root.selectedIndex") == 1 and not ev("root.renameMode"), (names, ev("root.selectedIndex")))

ev("root.enterDeleteMode('work')")
check("delete mode", ev("root.deleteMode") and ev("root.deleteButtonIndex") == 0)
key(Qt.Key_Right)
check("right arrow highlights confirm", ev("root.deleteButtonIndex") == 1)
key(Qt.Key_Return)
pump(40)
log = json.loads(h.eval(root, "JSON.stringify(fx.log)"))
check("enter kills the session", "tmux kill-session -t work" in log and not ev("root.deleteMode"), log[-3:])
names = [s["name"] for s in js("root.filteredSessions")]
check("list refreshed after kill", names == ["Create new session", "dev"], names)

ev("root.enterDeleteMode('dev')")
key(Qt.Key_Escape)
check("escape cancels delete", not ev("root.deleteMode"))

ev("root.selectedIndex = 0; resultsList.currentIndex = 0")
ev("searchInput.accepted()")
pump()
check("enter on create opens a terminal and closes the dashboard",
      js("TerminalService.ran") == ["tmux"] and ev("Visibilities.module") == "", js("TerminalService.ran"))
ev("root.searchText = 'fresh'")
pump()
ev("searchInput.accepted()")
check("named create", js("TerminalService.ran")[-1] == "tmux new -s 'fresh'")
ev("root.attachToSession('dev')")
check("attach", js("TerminalService.ran")[-1] == "tmux attach-session -t 'dev'")

h.exit(0 if ok else 1)
