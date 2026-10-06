"""Timers QML services offscreen over a stubbed backend:

* TimersService (real): timers.state -> rows / skew / tick, timers.event ->
  alarm (AlarmPlayer, real) and Pomodoro phase pause, call wrappers, errors,
  the notch hub state.
* TimerActivity (real provider): running timers as rings, ringing ones as
  pulsing alarms, paused hidden, stopwatch and reminders due soon; clicks
  stop a ringing timer or open the hub.
* FocusMode (real): DND on + "Focus" timer, end on the timer event with DND
  restored and a summary of the missed notifications.
* UtilityCommands (real): bind commands -> backend calls / hub / focus.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + str(detail) if detail else ""))


h = Harness("timers-service")
EN = json.loads((REPO / "translations/en.json").read_text())

h.singleton("qs.config", "Config", """QtObject {
    property var system: ({
        timers: { notchStyle: "ring", showSeconds: true, pulseOnFinish: true, alarmPanel: true, sound: true,
                  soundFile: "", alarmRepeat: 2, alarmInterval: 1, phaseSound: true, showStopwatch: true,
                  reminderLead: 15, clockClick: "popup", noteTitle: "" },
        focus: { minutes: 50, dnd: true, hideBadges: true, summary: true },
        pomodoro: { workTime: 1500, restTime: 300, autoStart: false, syncSpotify: false }
    })
    property var notifications: ({ dnd: { enabled: false } })
    property var bar: ({ use12hFormat: false, activities: { enabled: true, sources: { timers: true } } })
}""")
h.module("Quickshell", {
    "Singleton": "Item {}",
    "Quickshell": """pragma Singleton
QtObject {
    property string shellDir: "/shell"
    property var ran: []
    function execDetached(c) { ran = ran.concat([c]); }
}""",
})
h.singleton("qs.modules.globals", "GlobalStates", "QtObject { function focusedScreenName() { return 'DP-1'; } }")
h.module("qs.modules.theme", {"Icons": "pragma Singleton\nQtObject { property string timer: 'T'; property string alarm: 'A'; property string countdown: 'C'; property string watch: 'W'; property string downloadSimple: 'D' }"})

svc = "qs/modules/services"
h.module("qs.modules.services", {
    "I18n": "pragma Singleton\nQtObject { property var strings: (" + json.dumps(EN) + ")\n"
            "  function t(k) { var s = strings[k] || k; for (var i = 1; i < arguments.length; i++) s = s.replace('%' + i, arguments[i]); return s; } }",
    "BackendService": """pragma Singleton
QtObject {
    property var calls: []
    property var callbacks: []
    property var handler: null
    property var services: []
    function call(method, params, cb) { calls = calls.concat([{ method: method, params: JSON.parse(JSON.stringify(params || {})) }]); callbacks.push(cb || null); }
    function reply(i, result, error) { if (callbacks[i]) callbacks[i](result, error); }
    function last() { return calls.length ? calls[calls.length - 1] : null; }
    function addSubscription(s, cb) { services = s; handler = cb; return 1; }
    function emit(service, data) { handler(service, data); }
}""",
    "Notifications": """pragma Singleton
QtObject {
    property var list: []
    property var dnd: []
    property var sent: []
    function setDnd(on) { dnd = dnd.concat([on]); }
    function notifyInternal(o) { sent = sent.concat([o]); return null; }
}""",
    "StateService": """pragma Singleton
QtObject {
    property bool initialized: true
    property var state: ({})
    function get(k, d) { return state[k] !== undefined ? state[k] : d; }
    function set(k, v) { var s = Object.assign({}, state); s[k] = JSON.parse(JSON.stringify(v)); state = s; }
}""",
    "QuickNote": "pragma Singleton\nQtObject { property var added: []; property string title: 'Inbox'; function add(t) { added = added.concat([t]); return true; } }",
})
for name in ["TimersService", "FocusMode", "UtilityCommands"]:
    h.copy(f"modules/services/{name}.qml", dest=svc, siblings=False)
h._write_qmldir(h.root / svc, "qs.modules.services")
h.copy("modules/services/timers/AlarmPlayer.qml", dest=svc + "/timers", siblings=False)
h._write_qmldir(h.root / svc / "timers", "qs.modules.services.timers")
act = svc + "/activities"
for name in ["ActivityProvider", "TimerActivity"]:
    h.copy(f"modules/services/activities/{name}.qml", dest=act, siblings=False)
h._write_qmldir(h.root / act, "qs.modules.services.activities")

root = h.load("""
import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.services.activities
Item {
    readonly property var acts: TimerActivity.activities
}
""")


def ev(expr):
    return h.eval(root, expr)


def emit(service, data):
    ev(f"BackendService.emit({json.dumps(service)}, {json.dumps(data)})")
    QTest.qWait(5)


def calls():
    return ev("JSON.stringify(BackendService.calls)")


check("subscribes to the timers service", ev("BackendService.services.join(',')") == "timers")
check("not ready before the first state", ev("TimersService.ready") is False)

now = int(ev("Date.now()"))
view = {
    "now": now + 3000,  # backend clock 3 s ahead
    "active": True, "ringing": 0,
    "timers": [
        {"id": "t1", "name": "tea", "state": "running", "totalMs": 130000, "endsAt": now + 3000 + 65000, "createdAt": 1},
        {"id": "t2", "name": "", "state": "paused", "totalMs": 60000, "leftMs": 30000, "createdAt": 2},
    ],
    "stopwatch": {"state": "running", "startedAt": now + 3000 - 5000, "accumMs": 0, "laps": []},
    "reminders": [{"id": "r1", "message": "call mom", "at": now + 3000 + 600000}, {"id": "r2", "message": "later", "at": now + 3000 + 7200000}],
}
emit("timers.state", view)
check("ready + skew from view.now", ev("TimersService.ready") and abs(ev("TimersService.skew") - 3000) < 200)
check("rows: running first, then paused", ev("TimersService.timers.map(t => t.id).join(',')") == "t1,t2")
left = ev("TimersService.timers[0].leftMs")
check("time left counts with the skew", 63500 < left <= 65000, left)
check("stopwatch elapsed", 4500 < ev("TimersService.stopwatchMs") < 7000)
check("ticks while something runs", ev("TimersService.tick.running") is True)

acts = json.loads(ev("JSON.stringify(acts)"))
ids = [a["id"] for a in acts]
check("activity per running timer, stopwatch and soon reminder; paused and far reminder hidden",
      ids == ["timer:t1", "stopwatch", "reminder:r1"], ids)
t1 = acts[0]
check("ring style with label mm:ss and progress", t1["indicator"] == "ring" and t1["label"] in ("01:05", "01:04") and 0.45 < t1["progress"] < 0.51, t1)
check("detail is the name", t1["detail"] == "tea")
ev("Config.system = Object.assign({}, Config.system, { timers: Object.assign({}, Config.system.timers, { notchStyle: 'text', showSeconds: false }) })")
QTest.qWait(5)
t1 = json.loads(ev("JSON.stringify(acts[0])"))
check("text style: no ring, compact label", t1["indicator"] == "glyph" and t1["progress"] == -1 and t1["label"] == "2m", t1)

# Clicks: a running timer opens the hub on that screen
ev("TimerActivity.activate(acts[0], Qt.LeftButton, 'HDMI-1')")
check("click opens the hub", ev("TimersService.hubOpen") and ev("TimersService.hubScreen") == "HDMI-1" and ev("TimersService.hubMode") == "timer")
ev("TimersService.closeHub()")

# Ringing
view2 = dict(view, ringing=1, timers=[dict(view["timers"][0], state="ringing", finishedAt=now)])
emit("timers.state", view2)
ringing = json.loads(ev("JSON.stringify(acts[0])"))
check("ringing: pulsing alarm, error color", ringing["indicator"] == "dot" and ringing["color"] == "error" and ringing["label"] == EN["activities.pomodoro_done"], ringing)
check("ringingTimers", ev("TimersService.ringing") == 1)
emit("timers.event", {"kind": "timer", "id": "t1", "name": "tea", "done": True, "message": "Timer finished"})
check("alarm rings once now", ev("TimersService.alarm.ringing") and len(ev("JSON.stringify(Quickshell.ran)")) > 2)
first = json.loads(ev("JSON.stringify(Quickshell.ran[0])"))
check("tone through pw-play/paplay with the file as argv", first[0] == "sh" and first[4] == "/shell/assets/sound/polite-warning-tone.wav", first)
check("alarm screen = focused", ev("TimersService.alarmScreen") == "DP-1")
QTest.qWait(1300)
check("repeats every alarmInterval until alarmRepeat", ev("Quickshell.ran.length") == 2, ev("Quickshell.ran.length"))
QTest.qWait(1200)
check("stops after alarmRepeat rings", ev("Quickshell.ran.length") == 2 and not ev("TimersService.alarm.ringing"))
ev("TimerActivity.activate(acts[0], Qt.LeftButton, 'DP-1')")
check("click on a ringing timer dismisses it", json.loads(calls())[-1] == {"method": "timers.dismiss", "params": {"id": "t1"}})
emit("timers.event", {"kind": "timer", "id": "t1", "done": True})
emit("timers.state", view)
check("alarm stops when nothing rings", not ev("TimersService.alarm.ringing"))

# Pomodoro phase change: soft cue, paused (autoStart off)
ran = ev("Quickshell.ran.length")
emit("timers.event", {"kind": "pomodoro", "id": "t5", "phase": "break", "done": False})
check("phase change: chime", ev("Quickshell.ran.length") == ran + 1 and "notification-chime" in json.loads(ev("JSON.stringify(Quickshell.ran[Quickshell.ran.length - 1])"))[4])
check("autoStart off: the Pomodoro pauses", json.loads(calls())[-1] == {"method": "timers.pause", "params": {"id": "t5"}})
emit("timers.event", {"kind": "reminder", "id": "r1", "name": "call mom", "done": True})
check("a reminder plays once, no ringing loop", not ev("TimersService.alarm.ringing"))

# Call wrappers and errors
ev("TimersService.add('t1', '+1m')")
check("add", json.loads(calls())[-1] == {"method": "timers.add", "params": {"id": "t1", "spec": "+1m"}})
ev("TimersService.toggle('t1')")
check("toggle a running timer pauses it", json.loads(calls())[-1]["method"] == "timers.pause")
ev("TimersService.toggle('t2')")
check("toggle a paused timer resumes it", json.loads(calls())[-1]["method"] == "timers.resume")
ev("TimersService.dismiss('')")
check("dismiss all sends no id", json.loads(calls())[-1] == {"method": "timers.dismiss", "params": {}})
ev("TimersService.quick('10m tea')")
n = ev("BackendService.calls.length") - 1
ev(f"BackendService.reply({n}, null, {{ message: 'no timer' }})")
check("errors are kept in lastError", ev("TimersService.lastError") == "no timer")
ev("TimersService.startPomodoro(3000, 600)")
check("pomodoro lengths in seconds", json.loads(calls())[-1] == {"method": "timers.pomodoro", "params": {"work": 3000, "break": 600}})

# UtilityCommands
for cmd, want in [("timer:10m tea", {"method": "timers.quick", "params": {"text": "10m tea"}}),
                  ("stopwatch-toggle", {"method": "timers.stopwatch", "params": {"action": "toggle"}}),
                  ("timer-stop", {"method": "timers.dismiss", "params": {}}),
                  ("routine:morning", {"method": "routines.run", "params": {"id": "morning"}})]:
    check(f"command {cmd}", ev(f"UtilityCommands.run({json.dumps(cmd)})") and json.loads(calls())[-1] == want)
ev("UtilityCommands.run('quick-note')")
check("quick-note opens the hub in note mode", ev("TimersService.hubOpen") and ev("TimersService.hubMode") == "note")
ev("UtilityCommands.run('timer-input')")
check("timer-input switches the open hub to timer mode", ev("TimersService.hubOpen") and ev("TimersService.hubMode") == "timer")
ev("UtilityCommands.run('timer-input')")
check("again: closes", not ev("TimersService.hubOpen"))
check("unknown commands are not handled", ev("UtilityCommands.run('nope')") is False)

# Focus mode
ev("Notifications.list = [{ appName: 'Old', time: 1, replaceKey: '' }]")
ev("UtilityCommands.run('focus-toggle')")
check("focus: DND on", ev("Notifications.dnd.join(',')") == "true" and ev("FocusMode.active"))
start = json.loads(calls())[-1]
check("focus: a timer of the default length", start == {"method": "timers.start", "params": {"seconds": 3000, "name": EN["focus.timer_name"]}}, start)
n = ev("BackendService.calls.length") - 1
ev(f"BackendService.reply({n}, {{ timer: {{ id: 't9' }} }}, null)")
check("focus: remembers its timer", ev("FocusMode.timerId") == "t9")
check("focus: persisted", ev("StateService.state.focusMode.active") and ev("StateService.state.focusMode.timerId") == "t9")
check("focus: badges hidden", ev("FocusMode.hideBadges"))
t = int(ev("Date.now()"))
ev(f"Notifications.list = Notifications.list.concat([{{ appName: 'Telegram', time: {t + 10}, replaceKey: '' }}, {{ appName: 'Telegram', time: {t + 20} }}, {{ appName: 'Mail', time: {t + 30} }}, {{ appName: 'Yozakura', time: {t + 40}, replaceKey: 'timer-t9' }}])")
focus_view = dict(view, ringing=1, timers=[{"id": "t9", "name": "Focus", "state": "ringing", "totalMs": 3000000, "createdAt": 5}])
emit("timers.state", focus_view)
emit("timers.event", {"kind": "timer", "id": "t9", "name": "Focus", "done": True})
check("focus ends on its timer event", not ev("FocusMode.active"))
check("focus: DND restored", ev("Notifications.dnd.join(',')") == "true,false")
check("focus: its ringing timer is dismissed", json.loads(calls())[-1] == {"method": "timers.dismiss", "params": {"id": "t9"}})
QTest.qWait(900)
sent = json.loads(ev("JSON.stringify(Notifications.sent)"))
check("focus: one summary notification", len(sent) == 1, sent)
if sent:
    check("summary counts missed notifications per app", sent[0]["body"] == "3 notifications: Telegram (2), Mail", sent[0]["body"])
    check("summary replaces the timer notification", sent[0]["replaceKey"] == "timer-t9")

# Focus toggled off by hand: cancels its timer, no ringing
ev("FocusMode.start(25)")
n = ev("BackendService.calls.length") - 1
check("explicit length", json.loads(calls())[-1]["params"]["seconds"] == 1500)
ev(f"BackendService.reply({n}, {{ timer: {{ id: 't10' }} }}, null)")
emit("timers.state", dict(view, timers=[{"id": "t10", "name": "Focus", "state": "running", "totalMs": 1500000, "endsAt": now + 1500000, "createdAt": 6}]))
check("leftMs follows the timer", ev("FocusMode.leftMs") > 1000000)
ev("FocusMode.toggle(0)")
check("toggle off cancels the focus timer", json.loads(calls())[-1] == {"method": "timers.cancel", "params": {"id": "t10"}})
ev("FocusMode.start(0)")
n = ev("BackendService.calls.length") - 1
ev(f"BackendService.reply({n}, {{ timer: {{ id: 't11' }} }}, null)")
emit("timers.state", dict(view, timers=[{"id": "t11", "name": "Focus", "state": "running", "totalMs": 1, "endsAt": now + 100000, "createdAt": 7}]))
emit("timers.state", dict(view, timers=[]))
check("the focus timer cancelled elsewhere ends focus", not ev("FocusMode.active"))

print("timers service: state, activity, alarm, phases, calls, commands and focus mode " + ("passed" if ok_all else "FAILED"))
sys.exit(0 if ok_all else 1)
