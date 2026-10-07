"""Dashboard frame and composed home (modules/widgets/dashboard), offscreen
with the real kit and sample services (tests/lib/dashboard_env.py).

The composed home fills the widgets tab and the dashboard follows its size;
each icon toggle calls the same service as QuickControls and reflects it,
right-click opens its details; the levels write the sink and microphone
volume (the icons mute, the mic shows its live level) and the brightness,
the chevrons open the device lists; the player shows the track with play as
the one primary action; the calendar selects today and browses months; the
notifications are one line per app with per-app and global clear, then the
quiet empty state; the rail switches tabs (the
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
check(abs(ev(dash, "implicitHeight") - max(430, ev(home, "implicitHeight"))) < 1, "height follows the home")

# Toggles: one row of icon toggles, each calls its service and follows it;
# the name and state are the tooltip.
names = ("wifiToggle", "bluetoothToggle", "micToggle", "silenceToggle", "nightToggle", "awakeToggle", "gameToggle")
toggles = {n: h.find(home, n) for n in names}
QTest.qWait(50)
check(len({ev(t, "y") for t in toggles.values()}) == 1, "the toggles share one row")
check(ev(toggles["wifiToggle"], "tooltipText") == "Wi-Fi · On · Home 5G", "wifi tooltip names the network")
check(ev(toggles["bluetoothToggle"], "tooltipText") == "Bluetooth · On · Buds Pro", "bluetooth tooltip names the device")
for name, state in (("wifiToggle", "NetworkService.wifiEnabled"), ("bluetoothToggle", "BluetoothService.enabled"),
                    ("micToggle", "!Audio.source.audio.muted"), ("silenceToggle", "Notifications.silent"),
                    ("nightToggle", "NightLightClient.active"), ("awakeToggle", "CaffeineClient.inhibit"),
                    ("gameToggle", "GameModeClient.toggled")):
    before = ev(toggles[name], state)
    ev(toggles[name], "clicked()")
    after = ev(toggles[name], state)
    check(before != after, name + " toggles its service")
    check(ev(toggles[name], "active") == after, name + " follows the service state")
check(ev(toggles["micToggle"], "icon") == ev(home, "Icons.micSlash"), "a muted mic shows the slashed glyph")
ev(toggles["micToggle"], "clicked()")

# Details: right-click / hold opens Wi-Fi, Bluetooth or the input devices
# in place of the calendar and notifications; Done or the same toggle closes.
detail = h.find(home, "detail")
ev(toggles["micToggle"], "more()")
check(ev(home, "detail") == "input" and ev(detail, "visible") and not ev(cal_ := h.find(home, "calendar"), "visible"),
      "the mic opens the input devices")
check(ev(detail, "label") == "Input", "the detail is named")
ev(toggles["micToggle"], "more()")
check(ev(home, "detail") == "", "the same toggle closes it")
ev(toggles["wifiToggle"], "more()")
check(ev(home, "detail") == "wifi", "wifi opens its networks")
ev(detail, "actionTriggered()")
check(ev(home, "detail") == "" and ev(cal_, "visible"), "Done closes the details")

# Levels: volume, microphone and brightness; the icons mute; the chevrons
# open the device lists (a click on a device makes it the default); the mic
# track carries the live input level.
vol = h.find(home, "volumeSlider")
mic = h.find(home, "micSlider")
light = h.find(home, "lightSlider")
check(abs(ev(vol, "value") - 0.62) < 1e-6 and not ev(vol, "showValue"), "volume read, no number")
check(abs(ev(mic, "value") - 0.3) < 1e-6, "mic volume read")
check(abs(ev(light, "value") - 0.38) < 1e-6, "brightness read")
ev(vol, "setFraction(0.8)")
ev(mic, "setFraction(0.5)")
ev(light, "setFraction(0.7)")
check(abs(ev(vol, "Audio.sink.audio.volume") - 0.8) < 1e-6, "volume written")
check(abs(ev(mic, "Audio.source.audio.volume") - 0.5) < 1e-6, "mic volume written")
check(abs(ev(light, "Brightness.mon.brightness") - 0.7) < 1e-6, "brightness written")
ev(vol, "Audio.sink.audio.volume = 0.25")
check(abs(ev(vol, "value") - 0.25) < 1e-6, "the slider follows the service again")
ev(vol, "iconClicked()")
check(ev(vol, "Audio.sink.audio.muted") and ev(vol, "icon") == ev(vol, "Icons.speakerX"), "the speaker mutes")
check(abs(ev(mic, "level") - 0.8) < 0.01, "the mic shows its live level (peak 0.25 = -12 dB)")
ev(mic, "iconClicked()")
check(ev(mic, "Audio.source.audio.muted") and ev(mic, "level") < 0, "the mic mutes, the meter stops")
ev(mic, "iconClicked()")
ev(h.find(home, "outputDevices"), "clicked()")
check(ev(home, "detail") == "output" and ev(h.find(home, "outputDevices"), "active"), "the chevron opens the outputs")
QTest.qWait(50)
devices = h.find(home, "devices")
check(ev(devices, "count") == 2 and ev(devices, "visible"), "the output devices are listed")
first = item(devices, "deviceRow")
check(ev(first, "selected") and ev(first, "title") == "Speakers", "the default output is selected")
ev(first, "clicked()")
check(ev(devices, "Audio.defaults.length") == 1, "a click sets the default device")
ev(h.find(home, "inputDevices"), "clicked()")
check(ev(home, "detail") == "input" and not ev(devices, "output"), "the other chevron switches to the inputs")
ev(home, "detail = ''")

# Player: the track, the timeline, play as the single primary action.
check(ev(h.find(home, "title"), "text") == "Midnight City", "track title")
check(ev(h.find(home, "artist"), "text") == "M83 · Hurry Up, We're Dreaming", "artist · album")
check(abs(ev(h.find(home, "timeline"), "value") - 104 / 243) < 1e-6, "timeline position")
times = h.find(home, "times")
check(ev(times, "opacity") == 0 and not ev(h.find(home, "player"), "showTimes"), "the times hide until hovered")
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

# Notifications: one line per app, no caption; clear one app or all.
nlist = h.find(home, "notifList")
empty = h.find(home, "emptyState")
check(ev(nlist, "count") == 3 and not ev(empty, "visible"), "one row per app")
row = item(nlist, "notifRow")
check(ev(row, "title") == "Mira Tanaka · Sent the deck, take a look before the call" and ev(row, "subtitle") == "",
      "a row is one line")
ev(item(nlist, "clearGroup"), "clicked()")
check(ev(nlist, "Notifications.discarded.length") == 1, "the row clears its app")
ev(h.find(home, "clearAll"), "clicked()")
check(ev(nlist, "Notifications.cleared") == 1, "clear all discards everything")
QTest.qWait(50)
check(ev(empty, "visible"), "quiet empty state after clearing")

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

# One stable size for every tab: switching tabs never resizes the dashboard.
size = (ev(dash, "implicitWidth"), ev(dash, "implicitHeight"))
for tab in (1, 2, 3, 0):
    ev(win, "GlobalStates.dashboardCurrentTab = %d" % tab)
    QTest.qWait(60)
    check(ev(dash, "state.currentTab") == tab, "tab %d current" % tab)
    check((ev(dash, "implicitWidth"), ev(dash, "implicitHeight")) == size, "size stable on tab %d" % tab)
