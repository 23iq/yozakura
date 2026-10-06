"""Stub singletons of the timers stack (modules/services/TimersService.qml,
FocusMode.qml, QuickNote.qml) for QML tests that load views using them
(notch panels, DefaultView, the bar clock). They record calls in `calls`
and answer `parse()` from `intents` ({text: Intent}).
"""
import json
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

TIMERS_SERVICE = """pragma Singleton
QtObject {
    property var timers: []
    property var reminders: []
    property var stopwatch: ({ state: "idle", laps: [] })
    property real stopwatchMs: 0
    property bool stopwatchActive: false
    readonly property var ringingTimers: timers.filter(t => t.ringing)
    readonly property int ringing: ringingTimers.length
    readonly property var pomodoro: timers.find(t => !!t.pomodoro) || null
    property bool use12h: false
    property bool hubOpen: false
    property string hubScreen: ""
    property string hubMode: "timer"
    property string alarmScreen: ""
    property string lastError: ""
    property var view: ({ timers: [], reminders: [] })
    property real now: Date.now()
    property var calls: []
    property var intents: ({})
    property var quickError: null
    function rec(m, p) { calls = calls.concat([{ method: m, params: p }]); }
    function openHub(mode, screen) { hubMode = mode || "timer"; hubScreen = screen || ""; hubOpen = true; rec("openHub", { mode: hubMode, screen: hubScreen }); }
    function closeHub() { hubOpen = false; rec("closeHub", {}); }
    function toggleHub(mode, screen) { if (hubOpen) closeHub(); else openHub(mode, screen); }
    function parse(text, cb) { var i = intents[text]; cb(i || null, i ? "" : "not a time"); }
    function quick(text, cb) { rec("quick", { text: text }); if (cb) cb(quickError ? null : { intent: intents[text] || null }, quickError); }
    function call(m, p, cb) { rec(m, p); }
    function start(spec, name) { rec("start", { spec: spec, name: name }); }
    function startSeconds(s, name) { rec("start", { seconds: s, name: name }); }
    function startPomodoro(w, b) { rec("pomodoro", { work: w, break: b }); }
    function pause(id) { rec("pause", { id: id }); }
    function resume(id) { rec("resume", { id: id }); }
    function toggle(id) { rec("toggle", { id: id }); }
    function add(id, spec) { rec("add", { id: id, spec: spec }); }
    function reset(id) { rec("reset", { id: id }); }
    function cancel(id) { rec("cancel", { id: id }); }
    function dismiss(id) { rec("dismiss", { id: id }); }
    function stopwatchAction(a) { rec("stopwatch", { action: a }); }
    function reminderAdd(w, m) { rec("reminderAdd", { when: w, message: m }); }
    function reminderCancel(id) { rec("reminderCancel", { id: id }); }
}"""

FOCUS_MODE = """pragma Singleton
QtObject {
    property bool active: false
    property int defaultMinutes: 50
    property real leftMs: 0
    property bool hideBadges: false
    property var calls: []
    function start(m) { calls = calls.concat([["start", m]]); active = true; }
    function stop(c) { calls = calls.concat([["stop", c]]); active = false; }
    function toggle(m) { calls = calls.concat([["toggle", m]]); active = !active; }
}"""

QUICK_NOTE = """pragma Singleton
QtObject {
    property string title: "Inbox"
    property var added: []
    function add(t) { added = added.concat([t]); return true; }
}"""


def services() -> dict:
    """{type: body} for h.module("qs.modules.services", ...)."""
    return {"TimersService": TIMERS_SERVICE, "FocusMode": FOCUS_MODE, "QuickNote": QUICK_NOTE}


def copy_js(root: Path) -> None:
    """The pure helpers the views import relatively (../services/timers/*.js)."""
    d = root / "qs/modules/services/timers"
    d.mkdir(parents=True, exist_ok=True)
    for f in (REPO / "modules/services/timers").glob("*.js"):
        shutil.copy(f, d / f.name)


def js(value) -> str:
    return json.dumps(value)
