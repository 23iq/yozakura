"""TerminalService (real) offscreen: a plain terminal window starts with
$SHELL set to the login shell /etc/passwd has now (term.status loginShell),
so fish made the default shell in this session is what new terminals open;
without a known login shell the argv is unchanged.
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


h = Harness("terminal-service")
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


def last():
    return json.loads(h.eval(root, "ran()"))[-1]


h.eval(root, "open()")
check("no status yet: the terminal starts as configured", last() == ["kitty"], last())
h.eval(root, "setStatus({loginShell: '/usr/bin/fish', fishIsLoginShell: true})")
h.eval(root, "open()")
check("after chsh the terminal gets the new login shell", last() == ["env", "SHELL=/usr/bin/fish", "kitty"], last())
h.eval(root, "setStatus({loginShell: 'fish'})")
h.eval(root, "open()")
check("a shell that is not an absolute path is not passed", last() == ["kitty"], last())

print("terminal service " + ("passed" if ok_all else "FAILED"))
sys.exit(0 if ok_all else 1)
