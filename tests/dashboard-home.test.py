"""Dashboard frame and composed home (modules/widgets/dashboard), offscreen
with the real kit and sample services (tests/lib/dashboard_env.py).

The composed home fills the widgets tab and the dashboard follows its size;
each toggle chip calls the same service as QuickControls and reflects it;
the levels write the sink volume (the icon mutes) and the brightness; the
player shows the track with play as the one primary action; the calendar
selects today and browses months; the notification list shows rows, a
count and Clear, then the quiet empty state; the rail switches tabs (the
current one active) and offers the edit toggle only in bento mode.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.dashboard_env import DashboardEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = DashboardEnv("dashboard-home", overrides={"layout": {"dashboard": {"home": "composed"}}})
h = env.h
win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.widgets.dashboard
Window {
    width: 1100; height: 800; visible: true
    Dashboard { objectName: "dashboard"; width: implicitWidth; height: implicitHeight }
}""")
dash = h.find(win, "dashboard")


def check(cond, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def ev(obj, expr: str):
    return h.eval(obj, expr)


def item(root, name: str):
    """Find by objectName in the visual tree (Repeater delegates included)."""
    found = ev(root, "(function f(it) { if (it.objectName === %r) return it; "
                     "for (let i = 0; i < it.children.length; i++) { const r = f(it.children[i]); if (r) return r; } "
                     "return null; })({ objectName: '', children: children })" % name)
    check(found is not None, "item " + name)
    return found


QTest.qWait(100)
home = ev(dash, "widgetsItem")
check(home is not None and h.find(home, "header") is not None, "composed home loaded")
check(abs(ev(dash, "implicitWidth") - (ev(home, "implicitWidth") + ev(dash, "railWidth"))) < 1, "width follows the home")
check(abs(ev(dash, "implicitHeight") - max(300, ev(home, "implicitHeight"))) < 1, "height follows the home")

# Toggles: each chip calls its service and follows its state.
chips = {n: h.find(home, n) for n in ("wifiChip", "bluetoothChip", "silenceChip", "awakeChip", "gameChip")}
check(ev(chips["wifiChip"], "text") == "Home 5G" and ev(chips["wifiChip"], "active"), "wifi shows the SSID")
check(ev(chips["bluetoothChip"], "text") == "Buds Pro", "bluetooth shows the connected device")
# One row: all five chips on the same line; when the labels don't fit,
# inactive chips go icon-only together while active ones keep their label
QTest.qWait(50)
ys = {ev(c, "y") for c in chips.values()}
check(len(ys) == 1, "the five chips fit one row " + str(ys))
row = ev(chips["wifiChip"], "parent")
full = sum(ev(c, "fullWidth") for c in chips.values()) + 4 * ev(row, "spacing")
if full > ev(row, "width"):
    check(all(ev(chips[n], "showLabel") for n in ("wifiChip", "bluetoothChip")), "active chips keep labels")
    check(not any(ev(chips[n], "showLabel") for n in ("silenceChip", "awakeChip", "gameChip")),
          "inactive chips icon-only together")
    check(all(abs(ev(chips[n], "width") - ev(chips[n], "compactWidth")) < 1 for n in ("silenceChip", "gameChip")),
          "icon-only chips shrink to the icon")
for name, state in (("wifiChip", "NetworkService.wifiEnabled"), ("bluetoothChip", "BluetoothService.enabled"),
                    ("silenceChip", "Notifications.silent"), ("awakeChip", "CaffeineClient.inhibit"),
                    ("gameChip", "GameModeClient.toggled")):
    before = ev(chips[name], state)
    ev(chips[name], "clicked()")
    after = ev(chips[name], state)
    check(before != after, name + " toggles its service")
    check(ev(chips[name], "active") == after, name + " follows the service state")
check(ev(chips["wifiChip"], "text") == "Wi-Fi", "wifi off falls back to its name")

# Levels: the sliders read and write the sink volume and the brightness.
vol = h.find(home, "volumeSlider")
light = h.find(home, "lightSlider")
check(abs(ev(vol, "value") - 0.62) < 1e-6 and ev(vol, "valueText") == "62%", "volume read with its value")
check(abs(ev(light, "value") - 0.38) < 1e-6, "brightness read")
ev(vol, "setFraction(0.8)")
ev(light, "setFraction(0.7)")
check(abs(ev(vol, "Audio.sink.audio.volume") - 0.8) < 1e-6, "volume written")
check(abs(ev(light, "Brightness.mon.brightness") - 0.7) < 1e-6, "brightness written")
ev(vol, "Audio.sink.audio.volume = 0.25")
check(abs(ev(vol, "value") - 0.25) < 1e-6, "the slider follows the service again")
ev(vol, "iconClicked()")
check(ev(vol, "Audio.sink.audio.muted") and ev(vol, "icon") == ev(vol, "Icons.speakerX"), "the icon mutes")

# Player: the track, the timeline, play as the single primary action.
check(ev(h.find(home, "title"), "text") == "Midnight City", "track title")
check(ev(h.find(home, "artist"), "text") == "M83 · Hurry Up, We're Dreaming", "artist · album")
check(abs(ev(h.find(home, "timeline"), "value") - 104 / 243) < 1e-6, "timeline position")
play = h.find(home, "playButton")
check(ev(play, "primary"), "play is primary")
ev(play, "clicked()")
check(ev(play, "MprisController.calls") == 1, "play toggles the player")

# Calendar: today selected, months browse, the title returns to today.
cal = h.find(home, "calendar")
check(ev(cal, "cells.filter(c => c.today).length") == 1, "today in the month")
title = h.find(home, "monthTitle")
now_title = ev(title, "text")
ev(h.find(home, "nextMonth"), "clicked()")
check(ev(cal, "monthShift") == 1 and ev(title, "text") != now_title, "next month")
ev(h.find(home, "prevMonth"), "clicked()")
ev(h.find(home, "prevMonth"), "clicked()")
check(ev(cal, "monthShift") == -1, "previous month")
ev(cal, "monthShift = 0")
check(ev(title, "text") == now_title, "back to today")

# Notifications: a count, one row per app, Clear, then the empty state.
group = h.find(home, "notifGroup")
empty = h.find(home, "emptyState")
check(ev(group, "label") == "Notifications · 3" and ev(group, "actionText") == "Clear", "count and Clear")
check(ev(h.find(home, "notifList"), "count") == 3 and not ev(empty, "visible"), "one row per app")
ev(group, "actionTriggered()")
check(ev(group, "Notifications.cleared") == 1, "Clear discards all")
QTest.qWait(50)
check(ev(empty, "visible") and ev(group, "label") == "Notifications" and ev(group, "actionText") == "",
      "quiet empty state after Clear")

# Rail: tabs as IconButtons (current active), edit only in bento mode.
wall_tab = item(dash, "dashTab_wallpapers")
check(ev(item(dash, "dashTab_widgets"), "active") and not ev(wall_tab, "active"), "widgets tab active")
check(not ev(h.find(dash, "bentoEditToggle"), "visible"), "no edit toggle on the composed home")
ev(wall_tab, "clicked()")
check(ev(dash, "GlobalStates.dashboardCurrentTab") == 1 and ev(wall_tab, "active"), "rail navigates")
ev(h.find(dash, "settingsButton"), "clicked()")
check(ev(dash, "GlobalShortcuts.settings") == 1, "settings button")
ev(dash, "GlobalStates.dashboardCurrentTab = 0")
ev(dash, "Config.layout.dashboard = Object.assign({}, Config.layout.dashboard, { home: 'bento' })")
QTest.qWait(100)
edit = h.find(dash, "bentoEditToggle")
check(ev(dash, "!homeComposed") and ev(edit, "visible"), "bento mode offers the edit toggle")
ev(edit, "clicked()")
check(ev(dash, "bentoEditing") and ev(edit, "active"), "edit toggle switches bento editing")

print("dashboard-home: ok")
h.exit(0)
