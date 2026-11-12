"""AppSearch.launchApp (real) offscreen: a terminal emulator's desktop entry
(the launcher, the dock) starts with $SHELL set to the login shell the
terminal look reported (TerminalService.withLoginShell), so fish made the
default shell this session is what it opens; other apps start unchanged.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + str(detail) if detail else ""))


h = Harness("appsearch-terminal")
h.module("Quickshell", {
    "Singleton": "Item {}",
    "DesktopEntry": "QtObject {}",
    "DesktopEntries": "pragma Singleton\nQtObject { property var applications: ({ values: [] }) }",
    "Quickshell": "pragma Singleton\nQtObject {}",
})
h.module("Quickshell.Io", {
    "Ran": "pragma Singleton\nQtObject { property var list: [] }",
    "Process": """QtObject {
    property var command: []
    property bool running: false
    signal exited()
    onRunningChanged: if (running) Ran.list = Ran.list.concat([command])
}""",
})
svc = "qs/modules/services"
h.module("qs.modules.services", {
    "TerminalService": """pragma Singleton
QtObject {
    property string loginShell: ""
    function withLoginShell(argv) { return loginShell.startsWith("/") ? ["env", "SHELL=" + loginShell].concat(argv) : argv; }
}""",
    "UsageTracker": "pragma Singleton\nQtObject { function getUsageScore(id) { return 0 } }",
})
h.copy("modules/services/AppSearch.qml", dest=svc, siblings=False)
h._write_qmldir(h.root / svc, "qs.modules.services")

root = h.load("""
import QtQuick
import Quickshell.Io
import qs.modules.services
Item {
    function launch(app) { AppSearch.launchApp(app) }
    function ran() { return JSON.stringify(Ran.list) }
    function setLogin(s) { TerminalService.loginShell = s }
}
""", auto_stub=False)

KITTY = "{fileName: '/usr/share/applications/kitty.desktop', categories: ['System', 'TerminalEmulator']}"
FILES = "{fileName: '/usr/share/applications/nautilus.desktop', categories: ['System', 'FileManager']}"


def last():
    return json.loads(h.eval(root, "ran()"))[-1]


def argv_of(cmd):
    # bash -c '<fixed launch script>' launch ARGV...
    return cmd[4:] if cmd[:2] == ["bash", "-c"] else cmd


h.eval(root, f"launch({KITTY})")
check("login shell unknown: kitty as is", argv_of(last()) == ["gio", "launch", "/usr/share/applications/kitty.desktop"], last())
h.eval(root, "setLogin('/usr/bin/fish')")
h.eval(root, f"launch({KITTY})")
check("terminal entry gets the login shell", argv_of(last()) == ["env", "SHELL=/usr/bin/fish", "gio", "launch", "/usr/share/applications/kitty.desktop"], last())
h.eval(root, f"launch({FILES})")
check("other apps start unchanged", argv_of(last()) == ["gio", "launch", "/usr/share/applications/nautilus.desktop"], last())
h.eval(root, "launch({command: ['foot', '%U'], categories: ['TerminalEmulator']})")
check("command entry of a terminal gets it too", argv_of(last()) == ["env", "SHELL=/usr/bin/fish", "foot"], last())

print("appsearch terminal " + ("passed" if ok_all else "FAILED"))
sys.exit(0 if ok_all else 1)
