"""TerminalService (real) offscreen: a plain terminal window starts with
$SHELL set to the shell of a chsh made this session (term.status
terminalShell), so fish made the default shell in this session is what new
terminals open; without one (no chsh, or a $SHELL the user chose that differs
from passwd from the start) the argv is unchanged. Started from a separate Settings or
wizard process (ProcessRole) the terminal also loses the window variables.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness, process_role_qml  # noqa: E402

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + str(detail) if detail else ""))


def scene(name, role=""):
    h = Harness(name)
    h.module("qs.modules.globals", {"ProcessRole": process_role_qml(role)})
    h.singleton("qs.config", "Config", "QtObject { property var general: ({ terminal: 'kitty' }) }")
    h.module("Quickshell", {
        "Singleton": "Item {}",
        "Quickshell": """pragma Singleton
QtObject {
    property var ran: []
    function execDetached(c) { ran = ran.concat([c]); }
}""",
    })
    svc = "qs/modules/services"
    h.module("qs.modules.services", {
        "TerminalLookService": "pragma Singleton\nQtObject { property var status: null }",
    })
    h.copy("modules/services/TerminalService.qml", dest=svc, siblings=False)
    h._write_qmldir(h.root / svc, "qs.modules.services")

    root = h.load("""
import QtQuick
import Quickshell
import qs.modules.services
Item {
    function open() { TerminalService.open() }
    function ran() { return JSON.stringify(Quickshell.ran) }
    function setStatus(s) { TerminalLookService.status = s }
}
""", auto_stub=False)
    return h, root


h, root = scene("terminal-service")


def last():
    return json.loads(h.eval(root, "ran()"))[-1]


h.eval(root, "open()")
check("no status yet: the terminal starts as configured", last() == ["kitty"], last())
h.eval(root, "setStatus({loginShell: '/usr/bin/fish', fishIsLoginShell: true})")
h.eval(root, "open()")
check("a passwd shell alone (no chsh this session) keeps $SHELL", last() == ["kitty"], last())
h.eval(root, "setStatus({loginShell: '/usr/bin/fish', terminalShell: '/usr/bin/fish'})")
h.eval(root, "open()")
check("after chsh the terminal gets the new login shell", last() == ["env", "SHELL=/usr/bin/fish", "kitty"], last())
h.eval(root, "setStatus({loginShell: 'fish', terminalShell: 'fish'})")
h.eval(root, "open()")
check("a shell that is not an absolute path is not passed", last() == ["kitty"], last())

# A separate Settings / wizard process: the same argv, without the window
# variables (a shell.qml started from that terminal stays the main shell).
h2, root2 = scene("terminal-service-window", "settings")
h2.eval(root2, "setStatus({loginShell: '/usr/bin/fish', terminalShell: '/usr/bin/fish'})")
h2.eval(root2, "open()")
got = json.loads(h2.eval(root2, "ran()"))[-1]
check("from a window process: argv with the login shell, the window variables removed",
      isinstance(got, dict) and got.get("command") == ["env", "SHELL=/usr/bin/fish", "kitty"]
      and len(got.get("environment", {})) == 4 and all(v is None for v in got["environment"].values()), got)

print("terminal service " + ("passed" if ok_all else "FAILED"))
sys.exit(0 if ok_all else 1)
