"""The in-shell polkit agent (modules/polkit) on stubbed
Quickshell.Services.Polkit types shaped like Quickshell's own
(tests/lib/polkit_env.py): a request opens the dialog on the focused screen
with the flow's texts; submit passes the typed value once and empties the
field; a failed attempt shows the error and takes a retry; Cancel / Escape /
the caller cancelling close it; the next queued request replaces the
first; a locked session cancels; another agent holding the session (ours
not registered) shows nothing and logs one line; the setting off loads no
agent; the dry-run instance has no host; shell reload cancels a pending
request."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.polkit_env import POLKIT_MEMBERS, PolkitEnv, installed_qmltypes  # noqa: E402
from lib.waits import pump, settle, wait_until  # noqa: E402
from PySide6.QtCore import QEvent, QObject, Qt, qInstallMessageHandler  # noqa: E402
from PySide6.QtGui import QGuiApplication, QKeyEvent  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
failures: list[str] = []


def check(cond, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


# ---- the stubs have the members of the real types, and no others ----------
qmltypes = installed_qmltypes()
if qmltypes is not None:
    text = qmltypes.read_text()
    for type_name, members in POLKIT_MEMBERS.items():
        block = text[text.index(f'name: "qs::service::polkit::{type_name}"'):]
        block = block[:block.find("\n    Component {")] if "\n    Component {" in block else block
        props = re.findall(r'Property \{\s*name: "(\w+)"', block)
        sigs = [s for s in re.findall(r'Signal \{ name: "(\w+)"', block) if not s.endswith("Changed")]
        meths = re.findall(r'Method \{\s*name: "(\w+)"', block)
        check(sorted(props) == sorted(members["properties"]), f"{type_name} properties {props} != stub")
        check(sorted(sigs) == sorted(members["signals"]), f"{type_name} signals {sigs} != stub")
        check(sorted(meths) == sorted(members["methods"]), f"{type_name} methods {meths} != stub")
else:
    print("note: no installed quickshell-service-polkit.qmltypes, stub shape not cross-checked")

env = PolkitEnv("polkit-agent")
h = env.h

# Every console line (the agent's log), to count and to scan for secrets.
logs: list[str] = []
_prev = None


def _record(mode, ctx, msg):
    logs.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


_prev = qInstallMessageHandler(_record)

scene = h.load("""
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.polkit
import qs.polkittest
Item {
    id: scene
    property alias host: host
    property var screens: [left, right]
    ShellScreen { id: left; name: "DP-1" }
    ShellScreen { id: right; name: "HDMI-A-1" }
    Component { id: flowComp; AuthFlow {} }
    QtObject { id: alice; objectName: "alice"; property int id: 1000; property string string: "user"; property string displayName: "user"; property bool isGroup: false }
    QtObject { id: bob; objectName: "bob"; property int id: 1001; property string string: "admin"; property string displayName: "Admin"; property bool isGroup: false }
    function makeFlow(extra) {
        const props = Object.assign({ message: "Authentication is required to install software",
            actionId: "org.freedesktop.policykit.exec", cookie: "c1", identities: [alice], selectedIdentity: alice }, extra || {});
        return flowComp.createObject(scene, props);
    }
    function idents(n) { return n === 2 ? [alice, bob] : [alice]; }
    Component.onCompleted: Quickshell.screens = scene.screens
    PolkitHost { id: host; objectName: "host" }
}""", auto_stub=False)

ev = lambda expr: h.eval(scene, expr)  # noqa: E731


def agent():
    return scene.findChild(QObject, "polkitAgent")


def type_text(win, text: str) -> None:
    for ch in text:
        QGuiApplication.sendEvent(win, QKeyEvent(QEvent.KeyPress, Qt.Key_A, Qt.NoModifier, ch))
        QGuiApplication.sendEvent(win, QKeyEvent(QEvent.KeyRelease, Qt.Key_A, Qt.NoModifier, ch))


def windows():
    return [w for w in scene.findChildren(QObject, "polkitWindow")]


check(wait_until(lambda: agent() is not None), "the host loads the agent (setting on, module present)")
check(ev("PolkitService.available") is True, "PolkitService.available once the agent loaded")
a = agent()


def reported():
    """The last agent state the host sent the daemon, with its pid."""
    return ev("(() => { const s = BackendService.sent.filter(m => m.method === 'compositor.setPolkitState');"
              " return s.length ? s[s.length - 1].params.state + '@' + s[s.length - 1].params.pid : '' })()")


check(reported() == "pending@4242", f"loaded, not registered yet: the daemon is told pending, got {reported()!r}")
h.eval(a, "isRegistered = true")
check(ev("PolkitService.registered") is True, "registration is reported to PolkitService")
check(reported() == "registered@4242", f"registration is reported to the daemon, got {reported()!r}")
ev("BackendService.sent = []")
ev("BackendService.socketAvailable = false")
ev("BackendService.socketAvailable = true")
check(reported() == "registered@4242", "a reconnected daemon is told again")


def start(expr="scene.makeFlow()"):
    f = ev(expr)
    h.eval(a, "flow = null")
    a.setProperty("flow", f)
    settle()
    return f


# ---- a request opens the dialog on the focused screen ---------------------
ev('GlobalStates.focused = "HDMI-A-1"')
f1 = start()
check(len(windows()) == 1, f"one dialog window for the request, got {len(windows())}")
w = windows()[0] if windows() else None
check(w is not None and h.eval(w, "targetScreen.name") == "HDMI-A-1", "the dialog opens on the focused screen")
check(ev("PolkitService.dialogOpen") is True, "dialogOpen while waiting for the user")
check(any("authentication requested for org.freedesktop.policykit.exec" in m for m in logs), "the request is logged with its action id")

# ---- hotplug: the screen goes, the dialog comes back on the focused one ----
ev('GlobalStates.focused = "DP-1"')
ev("Quickshell.screens = [scene.screens[0]]")
settle()
ws = windows()
check(len(ws) == 1 and h.eval(ws[0], "targetScreen.name") == "DP-1", "the dialog moves to the focused screen when its output goes")
ev('GlobalStates.focused = "HDMI-A-1"')  # stale name of a gone output: first screen
ev("Quickshell.screens = scene.screens")
settle()

# ---- every output gone: unplaced, and back on the first one that returns ---
ev("Quickshell.screens = []")
settle()
check(windows() == [] and ev("PolkitService.dialogOpen") is False and h.eval(f1, "isCompleted") is False,
      "no output: no window, dialogOpen false, the request still waits")
ev('GlobalStates.focused = "DP-1"')
ev("Quickshell.screens = [scene.screens[0]]")
settle()
ws = windows()
check(len(ws) == 1 and h.eval(ws[0], "targetScreen.name") == "DP-1" and ev("PolkitService.dialogOpen") is True,
      "an output coming back after none shows the dialog again")
ev("Quickshell.screens = scene.screens")
settle()

# ---- the caller cancels ----------------------------------------------------
h.eval(f1, "cancelAuthenticationRequest()")  # what Quickshell does on polkitd's CancelAuthentication
settle()
check(windows() == [] and ev("PolkitService.dialogOpen") is False, "a request cancelled by its caller closes the dialog")
h.eval(a, "flow = null")
ev("PolkitLog.reset()")

# ---- the second request replaces the first --------------------------------
f2 = start()
f3 = ev("scene.makeFlow({ message: 'Authentication is required to change the system time', actionId: 'org.freedesktop.timedate1.set-time', cookie: 'c2' })")
a.setProperty("flow", f3)
settle()
ws = windows()
check(len(ws) == 1 and h.eval(ws[0], "flow.cookie") == "c2", "the next request in polkit's queue replaces the first cleanly")
h.eval(a, "flow = null")
settle()
check(windows() == [], "no dialog without a request")

# ---- locked session: cancelled, never shown -------------------------------
ev("PolkitLog.reset()")
ev("GlobalStates.lockscreenVisible = true")
f4 = start()
check(windows() == [] and h.eval(f4, "isCancelled") is True and ev("PolkitLog.cancels") == 1,
      "a request while locked is cancelled, no dialog")
h.eval(a, "flow = null")
ev("GlobalStates.lockscreenVisible = false")
f5 = start()
check(len(windows()) == 1, "after unlock a new request shows")
ev("GlobalStates.lockscreenVisible = true")
settle()
check(windows() == [] and h.eval(f5, "isCancelled") is True, "locking while the dialog is open cancels the request")
check(any("session locked" in m for m in logs), "the lock cancel is logged")
h.eval(a, "flow = null")
ev("GlobalStates.lockscreenVisible = false")

# ---- a request while no output exists opens once one appears ---------------
ev("Quickshell.screens = []")
settle()
f7 = start()
check(windows() == [] and ev("PolkitService.dialogOpen") is False, "a request with no output waits unplaced")
ev('GlobalStates.focused = "HDMI-A-1"')
ev("Quickshell.screens = scene.screens")
settle()
ws = windows()
check(len(ws) == 1 and h.eval(ws[0], "targetScreen.name") == "HDMI-A-1" and ev("PolkitService.dialogOpen") is True,
      "the waiting request opens on the output that appears")
h.eval(f7, "cancelAuthenticationRequest()")
h.eval(a, "flow = null")
settle()

# ---- reload / unload cancels a pending request ----------------------------
ev("PolkitLog.reset()")
f6 = start()
logs.clear()
ev("Config.system.polkitAgent = false")  # the host unloads the agent (as a reload would)
settle()
check(h.eval(f6, "isCancelled") is True and ev("PolkitLog.cancels") == 1, "unloading the agent cancels the pending request")
check(agent() is None and ev("PolkitService.available") is False and ev("PolkitService.registered") is False,
      "setting off: no agent, nothing registered")
check(reported() == "off@4242", f"setting off: the daemon is told off at once, got {reported()!r}")
pump(1200)
check(ev("Quickshell.detached.some(c => c[c.length - 1] === 'polkit-fallback')") is True,
      "turned off at runtime: the external agent is started (polkit-fallback)")

# ---- agent not registered (another agent holds the session) ---------------
ev("Config.system.polkitAgent = true")
check(wait_until(lambda: agent() is not None), "setting on again: agent loaded")
a = agent()
check(reported() == "pending@4242", "setting on again: pending until registered")
timer_logs = lambda: [m for m in logs if "in-shell agent is not registered" in m]  # noqa: E731
check(len(timer_logs()) == 0, "nothing logged before the registration had its time")
scene.findChild(QObject, "registrationCheck").setProperty("interval", 50)
pump(400)
check(len(timer_logs()) == 1, f"one log line when another agent holds the session, got {timer_logs()}")
check(ev("PolkitService.registered") is False and windows() == [], "not registered: nothing shown, the wizard keeps its fallback")
h.eval(a, "isRegistered = true")

# ---- the dialog ------------------------------------------------------------
dlg = h.load("""
import QtQuick
import QtQuick.Window
import Quickshell.Services.Polkit
import qs.modules.polkit
Window {
    id: win
    width: 640; height: 520; visible: true; color: "black"
    property alias dialog: dialog
    PolkitDialog { id: dialog; objectName: "dialog"; anchors.centerIn: parent; shown: true }
}""", auto_stub=False)
dlg.requestActivate()
wait_until(dlg.isActive)
d = h.find(dlg, "dialog")
ev("PolkitLog.reset()")
f = ev("scene.makeFlow()")
d.setProperty("flow", f)
h.eval(f, 'request("Password: ", false)')
settle()
title = h.find(dlg, "polkitTitle")
check(h.eval(title, "text") == "Authentication required", "title")
check(h.eval(h.find(dlg, "polkitMessage"), "text") == "Authentication is required to install software", "the polkit message is shown")
check(h.eval(h.find(dlg, "polkitAction"), "text") == "org.freedesktop.policykit.exec", "the action id is shown under it")
check(h.eval(h.find(dlg, "polkitIdentity"), "visible") is True and h.eval(h.find(dlg, "polkitIdentity"), "text") == "Authenticating as user",
      "one identity: named, no picker")
check(h.eval(h.find(dlg, "polkitIdentityPicker"), "parent.visible") is False, "no picker with one identity")
field = h.find(dlg, "polkitField")
check(h.eval(field, "placeholderText") == "Password", "the prompt polkit asks ('Password: ') is the field's placeholder")
check(h.eval(field, "passwordMode") is True, "masked while responseVisible is false")
check(wait_until(lambda: h.eval(field, "field.field.activeFocus")), "focus starts in the field")

# type, Enter: one submit with the typed value, field empty at once
type_text(dlg, "hunter2")
check(h.eval(field, "text") == "hunter2", "typing goes to the field")
QTest.keyClick(dlg, Qt.Key_Return)
settle()
check(ev("PolkitLog.submits") == 1 and ev("PolkitLog.lastValue === 'hunter2'") is True, "Enter submits the typed value once")
check(h.eval(field, "text") == "", "the field is emptied on submit")
check(h.eval(h.find(dlg, "polkitAuthenticate"), "enabled") is False, "Authenticate is off while polkit checks")

# a wrong password: error, cleared, focused for the retry
h.eval(f, 'showError("Sorry, that did not work.")')
h.eval(f, "completed(false)")
h.eval(f, 'request("Password: ", false)')
settle()
notice = h.find(dlg, "polkitNotice")
check(h.eval(notice, "visible") is True and h.eval(notice, "text") == "Sorry, that did not work.", "polkit's error line is shown")
check(h.eval(d, "noticeIsError") is True, "an error reads as an error")
check(wait_until(lambda: h.eval(field, "field.field.activeFocus")) and h.eval(field, "text") == "", "after a failure the field is empty and focused")
h.eval(f, 'showInfo("")')
settle()
check(h.eval(notice, "text") == "That did not work. Try again.", "without polkit's own text a failed attempt says so")
type_text(dlg, "second")
h.eval(h.find(dlg, "polkitAuthenticate"), "clicked()")
settle()
check(ev("PolkitLog.submits") == 2 and h.eval(field, "text") == "", "Authenticate submits the retry and empties the field")
check(h.eval(notice, "text") == "Waiting for the system…" and h.eval(d, "noticeIsError") is False,
      f"while the retry is checked the old failure is not shown, got {h.eval(notice, 'text')!r}")
# the retry fails: polkit's text and the failure are shown again
h.eval(f, 'showError("Sorry, that did not work.")')
h.eval(f, "completed(false)")
h.eval(f, 'request("Password: ", false)')
settle()
check(h.eval(notice, "text") == "Sorry, that did not work." and h.eval(d, "noticeIsError") is True, "the second failure is shown")
type_text(dlg, "third")
QTest.keyClick(dlg, Qt.Key_Return)
settle()
check(h.eval(notice, "text") == "Waiting for the system…" and h.eval(d, "noticeIsError") is False,
      "polkit's error from the last attempt is hidden while the next one is checked")
h.eval(f, 'showInfo("Checking with the server")')
settle()
check(h.eval(notice, "text") == "Checking with the server", "a new polkit message while checking is shown")
h.eval(f, "completed(true)")
settle()
check(h.eval(f, "isSuccessful") is True and ev("PolkitLog.cancels") == 0, "success: no cancel")

# fingerprint-like info without an answer expected
g = ev("scene.makeFlow()")
d.setProperty("flow", g)
h.eval(g, 'showInfo("Place your finger on the reader")')
settle()
check(h.eval(notice, "text") == "Place your finger on the reader" and h.eval(d, "noticeIsError") is False, "info lines are shown as info")
check(h.eval(field, "enabled") is False, "no answer asked: the field is off")
h.eval(g, 'request("Password: ", true)')
settle()
check(h.eval(field, "passwordMode") is False, "responseVisible shows the answer in clear")
check(wait_until(lambda: h.eval(field, "field.field.activeFocus")), "a new prompt takes the focus")

# Escape cancels
type_text(dlg, "abc")
QTest.keyClick(dlg, Qt.Key_Escape)
settle()
check(h.eval(g, "isCancelled") is True and ev("PolkitLog.cancels") == 1, "Escape cancels the request")
# Cancel button
k = ev("scene.makeFlow()")
d.setProperty("flow", k)
h.eval(k, 'request("Password: ", false)')
settle()
check(h.eval(field, "text") == "", "a new flow starts with an empty field")
h.eval(h.find(dlg, "polkitCancel"), "clicked()")
check(h.eval(k, "isCancelled") is True, "Cancel cancels the request")

# two identities: the picker, a pick selects it
m = ev("scene.makeFlow({ identities: scene.idents(2) })")
d.setProperty("flow", m)
h.eval(m, 'request("Password: ", false)')
settle()
picker = h.find(dlg, "polkitIdentityPicker")
check(h.eval(picker, "parent.visible") is True and h.eval(h.find(dlg, "polkitIdentity"), "visible") is False, "two identities: the picker")
check(h.eval(picker, "options.map(o => o.text).join(',')") == "user,Admin", "identities by display name")
h.eval(picker, "selected(1)")
check(h.eval(m, "selectedIdentity.string") == "admin" and h.eval(picker, "value") == 1, "a pick selects that identity")

# ---- secrets: never logged ------------------------------------------------
check(not any("hunter2" in x or "second" in x or "third" in x for x in logs), "the typed passwords never reach the log")

# ---- the dry-run instance has no host -------------------------------------
dry = (REPO / "onboarding-dryrun.qml").read_text()
check("PolkitHost" not in dry and "Polkit" not in dry, "onboarding-dryrun.qml registers no agent")
shell = (REPO / "shell.qml").read_text()
check(len(re.findall(r"^\s*PolkitHost \{\}", shell, re.M)) == 1, "shell.qml holds exactly one PolkitHost")
IMPORT = re.compile(r"^import Quickshell\.Services\.Polkit\b", re.M)
check(not any(IMPORT.search(p.read_text()) for p in [*(REPO / "modules").rglob("*.qml"), REPO / "shell.qml"]
              if p.parent.name != "polkit"), "only modules/polkit imports Quickshell.Services.Polkit")
host_src = (REPO / "modules/polkit/PolkitHost.qml").read_text()
check(not IMPORT.search(host_src) and 'source: "PolkitAgentScope.qml"' in host_src,
      "the host loads the agent by URL (a Quickshell without the module still starts)")

print(f"polkit-agent: {'ok' if not failures else 'FAILED'} ({len(failures)} failure(s))")
h.exit(1 if failures else 0)
