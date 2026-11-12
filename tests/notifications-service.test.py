"""Notifications service (modules/services/Notifications.qml) lifecycle, offscreen.

The real service and its helpers (hide queue, reaper, history file) run
against stubbed Quickshell types and a fake disk behind FileView:
- a burst of timeouts hides every popup (one shared hide step used to keep
  only the last id and left the others shown for good),
- popups that timed out lose their timer (a kept timer refired after resume),
- discarded / cleared notifications are destroyed after the grace period,
- saves are coalesced, compact, and flushed when the service goes away,
- the history is loaded once (a later reload keeps newer notifications) and
  nothing is written before it was read,
- notifications that arrive before the history is read survive its load as
  the same live objects (popup, timer, actions; a server notification keeps
  its id and idOffset, saved ids that could collide move instead),
- a missing history file (first run, cleared cache) counts as an empty
  history: the deferred reload of the file written meanwhile changes nothing.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import pump, wait_until  # noqa: E402

h = Harness("notifications-service")

DISK = r"""pragma Singleton
QtObject {
    property var files: ({})
    // [{ path, text, block, atomic }]
    property var writes: []
    property bool preload: true
    function write(path, text, block, atomic) {
        files[path] = text;
        writes = writes.concat([{ "path": path, "text": text, "block": block, "atomic": atomic }]);
    }
}"""

FILEVIEW = """import FakeDisk
QtObject {
    id: v
    property string path
    property bool blockWrites: false
    property bool atomicWrites: false
    property bool printErrors: true
    signal loaded()
    signal loadFailed(int error)
    function text() { return Disk.files[v.path] ?? ""; }
    function reload() { Qt.callLater(() => (v.path in Disk.files) ? v.loaded() : v.loadFailed(2)); }
    function setText(t) { Disk.write(v.path, t, v.blockWrites, v.atomicWrites); }
    Component.onCompleted: if (Disk.preload) reload()
}"""

h.module("FakeDisk", {"Disk": DISK})
h.module("Quickshell.Io", {"FileView": FILEVIEW})
h.module("Quickshell", {
    "Singleton": "Item {}",
    "Quickshell": "pragma Singleton\nQtObject { property string shellDir: \"\"; function execDetached(a) {} }",
    "DesktopEntries": "pragma Singleton\nQtObject { property var applications: ({ values: [] }); "
                      "function byId(i) { return null } }",
})
h.module("Quickshell.Services.Notifications", {
    "NotificationServer": "QtObject { property bool actionsSupported; property bool bodyHyperlinksSupported; "
                          "property bool bodyImagesSupported; property bool bodyMarkupSupported; "
                          "property bool bodySupported; property bool imageSupported; property bool keepOnReload; "
                          "property bool persistenceSupported; property var extraHints; "
                          "property var trackedNotifications: ({ values: [] }); signal notification(var notification) }",
    "Notification": "QtObject { property int id; property string summary; property string body; "
                    "property string appIcon; property string appName; property string desktopEntry; "
                    "property string image; property int urgency: 1; property var actions: []; "
                    "property bool tracked; property int expireTimeout: -1; property var hints: ({}); "
                    "property int invokes: 0; property int dismissed: 0; function dismiss() { dismissed++ } "
                    "signal closed(int reason) }",
    "NotificationUrgency": "QtObject { enum Urgency { Low, Normal, Critical } }",
})
h.module("qs.modules.services", {
    "SuspendManager": "pragma Singleton\nQtObject { property bool isSuspending: false; signal wakingUp() }",
    "BackendService": "pragma Singleton\nQtObject { function addSubscription(s, cb) { return 1 } "
                      "function call(m, p, cb) {} }",
    "I18n": "pragma Singleton\nQtObject { function t(k) { return k } function has(k) { return false } }",
    "YozdService": "pragma Singleton\nQtObject { property var clients: ({ values: [] }); function dispatch(c) {} }",
})
h.module("qs.modules.globals", {})
h.singleton("qs.config", "Config",
            "QtObject { property var notifications: ({ maxVisible: 10, historySize: 100, groupByApp: true }) }")

# The deferred history reload runs 2 s after start; 300 ms here.
h.copy("modules/services/Notifications.qml", strip_singleton=True, siblings=False,
       replace={"interval: 2000": "interval: 300"})
for helper in ("NotificationHistoryFile", "NotificationHideQueue", "NotificationReaper"):
    h.copy(f"modules/services/{helper}.qml", siblings=False)
h.stub("NotificationRules", """QtObject {
    property bool silent: false
    property string presentation: "notch"
    property string cornerPosition: "top-right"
    function decide(info) {
        return { "popup": true, "timeout": info.expireTimeout > 0 ? info.expireTimeout : 5000,
                 "priority": false, "sound": false };
    }
    function playSound(h) {}
    function setDnd(o) {}
    function toggleDnd() {}
    function setFocusSilent(o) {}
    function showsOnScreen(n) { return true }
}""")

root = h.load("""
import QtQuick
import FakeDisk
import Quickshell.Services.Notifications
Item {
    id: harnessRoot
    property var seenTimeouts: []
    property alias loader: loader
    // A live D-Bus notification with a "default" action that counts invokes
    Component {
        id: serverComp
        Notification {
            id: sn
            actions: [({ "identifier": "default", "text": "Open", "invoke": () => sn.invokes++ })]
        }
    }
    function serverNotif(server, nid, summary) {
        const n = serverComp.createObject(harnessRoot, { "id": nid, "summary": summary, "appName": "Chat" });
        server.trackedNotifications = { "values": server.trackedNotifications.values.concat([n]) };
        server.notification(n);
        return n;
    }
    Loader {
        id: loader
        sourceComponent: Component {
            Notifications {
                onTimeout: id => harnessRoot.seenTimeouts = harnessRoot.seenTimeouts.concat([id])
            }
        }
    }
}""")

fails: list[str] = []


def check(cond, msg):
    print(("PASS " if cond else "FAIL ") + msg)
    if not cond:
        fails.append(msg)


def svc():
    return h.eval(root, "loader.item")


def ev(expr):
    """Evaluate inside Notifications.qml (its ids and members), through one of
    its own children (the history file): the service object itself lives in
    the loader's context."""
    inner = next(c for c in svc().children() if c.property("debounce") is not None)
    return h.eval(inner, expr)


def js(expr):
    return json.loads(ev("JSON.stringify(" + expr + ")"))


def disk(expr):
    return json.loads(h.eval(root, "JSON.stringify(" + expr + ")"))


history_path = ev("historyFile.path")


def writes():
    return [w for w in disk("Disk.writes") if w["path"] == history_path]


def popup(summary, timeout):
    return ev(f'notifyInternal({{ "summary": "{summary}", "expireTimeout": {timeout} }}).id')


# --- A: history on disk, preloaded -------------------------------------------
old = [{"id": i, "appName": "Mail", "summary": f"old {i}", "body": "", "time": i, "actions": [],
        "appIcon": "", "image": "", "urgency": "1"} for i in (5, 9)]
h.eval(root, f"Disk.files[{json.dumps(history_path)}] = {json.dumps(json.dumps(old, indent=2))}")
h.eval(root, "loader.active = false")
h.eval(root, "loader.active = true")
wait_until(lambda: ev("historyLoaded") and ev("list.length") == 2)
check(ev("idOffset") == 10, "pretty-printed history loads; idOffset above the saved ids")

# Arrived before the deferred reload (300 ms): the reload must not drop it.
early = popup("early", 60000)
pump(500)
check(early in js("list.map(n => n.id)"), "deferred reload keeps a notification received before it")
check(ev("list.length") == 3, f"history not loaded twice: {ev('list.length')}")

# A burst of timeouts within the hide animation: every popup hides.
a = popup("a", 100)
b = popup("b", 150)
c = popup("c", 200)
wait_until(lambda: not any(i in js("popupList.map(n => n.id)") for i in (a, b, c)))
check(all(i in disk("seenTimeouts") for i in (a, b, c)), "timeout() for every popup of the burst")
check(js("list.filter(n => [%d, %d, %d].includes(n.id) && n.timer !== null).length" % (a, b, c)) == 0,
      "timed out popups dropped their timer")
check(early in js("popupList.map(n => n.id)"), "a popup with time left stays")

# Saves are coalesced and compact.
wait_until(lambda: not ev("historyFile.writeTimer.running"))
before = len(writes())
for i in range(5):
    popup(f"burst {i}", 60000)
pump(150)
check(len(writes()) == before, "no write while notifications keep coming")
wait_until(lambda: len(writes()) > before)
pump(700)
check(len(writes()) == before + 1, f"one write for five notifications: {len(writes()) - before}")
text = writes()[-1]["text"]
saved = json.loads(text)
check("\n" not in text, "history written compact")
check({5, 9}.issubset({n["id"] for n in saved}) and any(n["summary"] == "burst 4" for n in saved),
      "saved history has the loaded and the new notifications")

# Dropped notifications are destroyed after the grace period.
ev("reaper.grace = 50")
destroyed: list[int] = []
objs = {}
for nid in (a, b):
    obj = ev(f"list.find(n => n.id === {nid})")
    objs[nid] = obj
    obj.destroyed.connect(lambda *_args, nid=nid: destroyed.append(nid))
ev(f"discardNotification({a})")
check(a not in js("list.map(n => n.id)"), "discarded notification left the list")
wait_until(lambda: a in destroyed)
check(b not in destroyed, "a notification still listed is kept")
ev(f"discardNotifications([{b}])")
wait_until(lambda: b in destroyed)
check(True, "discarded notification objects destroyed")

# Leaving flushes a pending save (blocking write).
popup("last words", 60000)
check(ev("historyFile.writeTimer.running"), "save pending")
n_before = len(writes())
h.eval(root, "loader.active = false")
pump(50)
check(len(writes()) == n_before + 1 and writes()[-1]["block"], "pending save flushed on destruction")
check(any(n["summary"] == "last words" for n in json.loads(writes()[-1]["text"])), "flushed save is current")

# --- B: no preload; nothing is written before the history was read ---------
# The saved history also holds an id (1) that the first live server
# notification of this run gets: the live one must keep it.
old_b = old + [{"id": 1, "appName": "Mail", "summary": "old 1", "body": "", "time": 1, "actions": [],
                "appIcon": "", "image": "", "urgency": "1"}]
h.eval(root, "Disk.preload = false")
h.eval(root, f"Disk.files[{json.dumps(history_path)}] = {json.dumps(json.dumps(old_b))}")
h.eval(root, "Disk.writes = []")
h.eval(root, "loader.active = true")
ev("reaper.grace = 50")
startup = ev('notifyInternal({ "summary": "startup", "expireTimeout": 60000, "actions": [{ "identifier": "go", "text": "Go" }], '
             '"actionHandlers": { "go": id => { root.internalIdCounter += 1000 } } })')
startup_id = startup.property("id")
server_obj = ev("root.parent.parent.serverNotif(notifServer, 1, 'live chat')")
pump(50)
live_server = ev("list.find(n => n.notification !== null)")
check(live_server is not None and live_server.property("id") == 1, "a server notification before the load gets id 1")
destroyed_live: list[str] = []
startup.destroyed.connect(lambda *_a: destroyed_live.append("startup"))
live_server.destroyed.connect(lambda *_a: destroyed_live.append("server"))
pump(200)
check(writes() == [], "no write before the history was read")
wait_until(lambda: ev("historyLoaded"))
wait_until(lambda: len(writes()) > 0)
saved = json.loads(writes()[-1]["text"])
check({"old 5", "old 9", "old 1"}.issubset({n["summary"] for n in saved}), "history kept after startup notifications")
check({"startup", "live chat"}.issubset({n["summary"] for n in saved}), "the startup notifications are saved too")
ids = js("list.map(n => n.id)")
check(len(ids) == len(set(ids)) == 5, f"one entry each, no id twice: {ids}")
check(ev(f"list.find(n => n.id === {startup_id}) === list.find(n => n.summary === 'startup')"), "startup notification kept its id")
check(ev("list.find(n => n.summary === 'startup').popup && !list.find(n => n.summary === 'startup').isCached"),
      "the startup notification is still a live popup")
check(ev("list.find(n => n.summary === 'startup').timer !== null"), "its popup timer is kept")
check(ev("list.find(n => n.id === 1).summary") == "live chat", "the live server notification keeps id 1")
check(ev("list.find(n => n.id === 1).popup && !list.find(n => n.id === 1).isCached"), "the live server notification is still a popup")
check(ev("idOffset") == 0, "idOffset does not move under live server notifications")
check(all(i < 0 for i in js("list.filter(n => n.isCached).map(n => n.id)")),
      "saved ids that a server id could reach moved out of the way")
counter = ev("internalIdCounter")
check(ev(f"attemptInvokeAction({startup_id}, 'go', false)") and ev("internalIdCounter") == counter + 1000,
      "the startup notification's action still runs")
check(ev("attemptInvokeAction(1, 'default', false)") and server_obj.property("invokes") == 1,
      "the live server notification's action still reaches the sender")
pump(150)
check(destroyed_live == [], f"live notifications are never retired by the load: {destroyed_live}")
ev("historyFile.reload()")
pump(100)
check(len(js("list.map(n => n.id)")) == 5, "a later reload changes nothing")
h.eval(root, "loader.active = false")
pump(50)

# --- C: first run, no history file; the deferred reload finds the file
# written meanwhile and must not replace the live notification -----------
for preload in (True, False):
    h.eval(root, f"Disk.preload = {'true' if preload else 'false'}")
    h.eval(root, "Disk.files = ({})")
    h.eval(root, "Disk.writes = []")
    h.eval(root, "loader.active = true")
    ev("reaper.grace = 50")
    first = ev('notifyInternal({ "summary": "first run", "expireTimeout": 60000 })')
    first_id = first.property("id")
    gone: list[int] = []
    first.destroyed.connect(lambda *_a, gone=gone: gone.append(1))
    if not preload:
        ev("historyFile.reload()")  # the first read of the missing file
    wait_until(lambda: ev("historyLoaded"))
    wait_until(lambda: len(writes()) > 0)
    offset = ev("idOffset")
    ev("historyFile.reload()")  # what the deferred reload does at 2 s
    pump(400)
    tag = "preloaded" if preload else "deferred"
    check(js("list.map(n => n.id)") == [first_id], f"{tag}: the list is the live notification only")
    check(ev("list[0].popup && !list[0].isCached"), f"{tag}: missing history: the popup stays live")
    check(ev("idOffset") == offset, f"{tag}: idOffset unchanged by the reload")
    check(gone == [], f"{tag}: the live notification is not destroyed")
    h.eval(root, "loader.active = false")
    pump(50)

if fails:
    print(f"{len(fails)} failure(s)")
h.exit(1 if fails else 0)
