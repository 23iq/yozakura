"""Dashboard stage home (modules/widgets/dashboard/stage), offscreen with the
real kit and sample services (tests/lib/dashboard_env.py).

The stage is the default home; the header shows the time, the labelled tab
chips and settings; the hero plays the track, takes its tone from the art
(off with layout.dashboard.heroTint) and, with nothing playing, shows the
greeting and the clock while the header keeps only the date; NEXT leads with
the Pomodoro, then the events, or one calm line when nothing is coming; the
week marks today and opens the month detail; the notifications have a label
and clear-all; the toggles open their details in the right column; the
metrics strip opens the metrics tab and hides with layout.dashboard.showMetrics.
"""
import sys
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.dashboard_env import DashboardEnv  # noqa: E402
from PySide6.QtGui import QColor, QImage  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.widgets.dashboard
Window {
    width: 1100; height: 800; visible: true
    Dashboard { objectName: "dashboard"; width: implicitWidth; height: implicitHeight }
}"""


def check(cond, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def art_file() -> str:
    """A small saturated blue cover."""
    img = QImage(32, 32, QImage.Format.Format_ARGB32)
    img.fill(QColor(40, 70, 220))
    path = Path(tempfile.mkdtemp(prefix="stage-art-")) / "cover.png"
    img.save(str(path))
    return "file://" + str(path)


def scene(name: str, **kw):
    env = DashboardEnv(name, **kw)
    win = env.load(SCENE)
    QTest.qWait(150)
    return env, env.h, env.h.find(win, "dashboard")


def item(h, root, name: str):
    """Find by objectName in the visual tree (Repeater delegates included)."""
    found = h.eval(root, "(function f(it) { if (it.objectName === %r) return it; "
                         "for (let i = 0; i < it.children.length; i++) { const r = f(it.children[i]); if (r) return r; } "
                         "return null; })({ objectName: '', children: children })" % name)
    check(found is not None, "item " + name)
    return found


def count(h, root, name: str) -> int:
    return h.eval(root, "(function f(it) { let n = it.objectName === %r && it.visible ? 1 : 0; "
                        "for (let i = 0; i < it.children.length; i++) n += f(it.children[i]); return n; })"
                        "({ objectName: '', visible: false, children: children })" % name)


now = datetime.now()
soon = now + timedelta(minutes=40)
events = ('[{"date": "%s", "time": "%s", "title": "Sync with Mira"}, {"date": "%s", "time": "10:00", "title": "Dentist"}]'
          % (soon.strftime("%Y-%m-%d"), soon.strftime("%H:%M"), (now + timedelta(days=1)).strftime("%Y-%m-%d")))

# --- Playing, with a Pomodoro and events -----------------------------------
env, h, dash = scene("dashboard-stage", art=art_file(), timers=[{"name": "", "leftMs": 600000, "pomodoro": True}])
ev = h.eval
check(ev(dash, "home") == "stage", "the stage is the default home")
stage = ev(dash, "widgetsItem")
check(h.find(stage, "hero") is not None, "stage home loaded")
check(abs(ev(dash, "implicitWidth") - ev(stage, "implicitWidth")) < 1, "width follows the stage")
check(ev(item(h, dash, "clock"), "visible"), "header shows the time while playing")
check(ev(item(h, dash, "dashTab_metrics"), "text") == "Metrics", "tab chips are labelled")

hero = h.find(stage, "hero")
check(ev(item(h, hero, "heroPlayer"), "visible") and not ev(item(h, hero, "heroIdle"), "visible"), "hero plays")
check(ev(item(h, hero, "title"), "text") == "Midnight City", "hero title")
check(ev(item(h, hero, "playButton"), "primary"), "play is the one primary action")
for _ in range(30):
    if ev(hero, "alpha") > 0:
        break
    QTest.qWait(50)
check(ev(hero, "tinted") and ev(hero, "alpha") > 0, "the art tints the hero")
tone = ev(hero, "toneRgb ? toneRgb.b - toneRgb.r : 0")
check(tone > 0.3, "the tone follows the (blue) art")

cal = h.find(stage, "calendarEvents")
ev(cal, "available = true")
ev(cal, "this.events = " + events)
QTest.qWait(50)
nxt = h.find(stage, "next")
check(ev(nxt, "rows[0].kind") == "pomodoro", "the Pomodoro leads NEXT")
check(ev(nxt, "rows[1].title") == "Sync with Mira", "then the soonest event")
check(ev(nxt, "subText(rows[1])") in ("in 40 min", "in 39 min"), "relative time of the event")
check(count(h, nxt, "nextRow") >= 3, "NEXT lists several rows")
check(ev(item(h, nxt, "nextTime"), "text") == "10:00", "the Pomodoro shows its countdown")

week = h.find(stage, "week")
check(count(h, week, "weekToday") == 1, "the week marks today")
check(count(h, week, "eventDot") >= 1, "days with events are dotted")
ev(week, "openMonth()")
QTest.qWait(50)
check(ev(stage, "detail") == "month" and ev(item(h, stage, "month"), "visible"), "the week opens the month")
check(not ev(nxt, "visible"), "the month takes the right column")
ev(h.find(stage, "detail"), "done()")
check(ev(stage, "detail") == "" and ev(nxt, "visible"), "done closes the month")

notes = h.find(stage, "notifications")
check(ev(notes, "label") == "Notifications" and ev(notes, "actionText") == "Clear all", "notifications labelled with clear-all")
ev(notes, "actionTriggered()")
check(ev(dash, "Notifications.cleared") == 1, "clear-all clears")

ev(h.find(stage, "bluetoothToggle"), "more()")
QTest.qWait(50)
check(ev(stage, "detail") == "bluetooth", "a toggle opens its detail")
ev(stage, "detail = ''")

metrics = h.find(stage, "metrics")
check(ev(metrics, "visible"), "metrics strip shown")
ev(metrics, "open()")
check(ev(dash, "GlobalStates.dashboardCurrentTab") == 2, "the strip opens the metrics tab")
check(ev(item(h, dash, "dashTab_metrics"), "active"), "metrics chip active")
check(ev(item(h, dash, "clock"), "visible"), "the header shows the time on other tabs")
ev(dash, "GlobalStates.dashboardCurrentTab = 0")
QTest.qWait(50)

ev(dash, "Config.layout.dashboard = Object.assign({}, Config.layout.dashboard, { showMetrics: false, heroTint: false })")
QTest.qWait(800)
check(not ev(metrics, "visible"), "showMetrics off hides the strip")
check(not ev(hero, "tinted") and not ev(item(h, hero, "heroTint"), "visible"), "heroTint off drops the tint")
check(not ev(h.find(dash, "bentoEditToggle"), "visible"), "no edit toggle on the stage")
ev(dash, "Config.layout.dashboard = Object.assign({}, Config.layout.dashboard, { home: 'bento' })")
QTest.qWait(100)
check(ev(h.find(dash, "bentoEditToggle"), "visible"), "bento mode offers the edit toggle in the header")

# --- Idle, nothing coming, no notifications --------------------------------
env2, h2, dash2 = scene("dashboard-stage-idle", playing=False, notifications=[], timers=[])
stage2 = h2.eval(dash2, "widgetsItem")
hero2 = h2.find(stage2, "hero")
check(h2.eval(item(h2, hero2, "heroIdle"), "visible") and not h2.eval(item(h2, hero2, "heroPlayer"), "visible"), "idle hero")
check(h2.eval(item(h2, hero2, "greeting"), "text").startswith("Good"), "idle hero greets")
check(h2.eval(item(h2, hero2, "heroClock"), "text") != "", "idle hero shows the clock")
check(not h2.eval(item(h2, dash2, "clock"), "visible"), "the header leaves the time to the idle hero")
check(h2.eval(hero2, "tinted") and h2.eval(hero2, "toneRgb") is None, "idle: the accent floods the hero, no art tone")
nxt2 = h2.find(stage2, "next")
check(h2.eval(item(h2, nxt2, "nextEmpty"), "visible") and count(h2, nxt2, "nextRow") == 0, "nothing coming: one calm line")
check(h2.eval(item(h2, stage2, "emptyState"), "visible"), "no notifications: the quiet line")

print("dashboard-stage: ok")
h2.exit(0)
