"""The dashboard's tool tabs offscreen (tests/lib/dashtabs_env.py), built
from the kit.

Metrics: one meter per resource (CPU, RAM, each GPU, each disk) in its
series colour with its value and temperature, the interval stepper (100 ms
steps, never under 100, saved), the zoom slider (saved, rounded) and the
chart painting. Audio mixer: the output / input segments swap the device
rows (the default selected) and the volumes (device + app streams, the
empty state), mute shows the danger look. EasyEffects: preset chips load
presets (the loaded one active), the switch bypasses. Settings rows (Live
Activities): toggle, segmented selector, clamped number field.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.dashtabs_env import DashTabsEnv  # noqa: E402
from lib.settings_env import DEFAULT_PALETTE  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

# The series colours come from the palette's named colours.
SERIES = {"red": "#ff5555", "cyan": "#55ffff", "yellow": "#ffff55", "green": "#55ff55", "blue": "#5555ff",
          "magenta": "#ff55ff"}
env = DashTabsEnv("dashboard-tabs", palette={**DEFAULT_PALETTE, **SERIES})
h = env.h


def check(cond, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def ev(obj, expr: str):
    return h.eval(obj, expr)


def items(root, name: str) -> list:
    """Every item named `name` in the visual tree (Repeater delegates included)."""
    out, stack = [], [root]
    while stack:
        it = stack.pop()
        if it.objectName() == name:
            out.append(it)
        stack.extend(reversed(it.childItems()))
    return out


def item(root, name: str):
    found = items(root, name)
    check(len(found) > 0, "item " + name)
    return found[0]


# --- metrics
win = env.scene("MetricsTab {}", 860, 430)
QTest.qWait(150)
tab = win.findChild(QQuickItem, "view")
lines = items(tab, "resourceLine")
check(len(lines) == 6, "a meter per CPU, RAM, GPU and disk (%d)" % len(lines))
values = sorted(round(ev(x, "value"), 2) for x in lines)
check(values == [0.12, 0.23, 0.37, 0.41, 0.48, 0.72], "meter values %s" % values)
colors = sorted(ev(x, "fillColor.toString()") for x in lines)
want = sorted(SERIES[k] for k in ("red", "cyan", "red", "green", "yellow", "yellow"))
check(colors == want, "series colours (CPU red, RAM cyan, GPUs by vendor, disks yellow): %s" % colors)

text = item(tab, "intervalText")
check(ev(text, "text") == "2000ms", "interval shown")
ev(item(tab, "intervalUp"), "clicked()")
check(ev(text, "text") == "2100ms", "interval steps up by 100 ms")
check(ev(text, "StateService.get('metricsRefreshInterval', 0)") == 2100, "interval saved")
for _ in range(30):
    ev(item(tab, "intervalDown"), "clicked()")
check(ev(text, "text") == "100ms", "interval never under 100 ms")

slider = item(tab, "zoomSlider")
check(abs(ev(slider, "value") - 1) < 1e-6, "zoom slider at the default zoom")
ev(slider, "setFraction(0.5)")
check(abs(ev(tab, "chartZoom") - 1.6) < 1e-6, "zoom from the slider, one decimal (%s)" % ev(tab, "chartZoom"))
check(abs(ev(text, "StateService.get('metricsChartZoom', 0)") - 1.6) < 1e-6, "zoom saved")

chart = item(tab, "metricsChart")
check(ev(chart, "width") > 300 and ev(chart, "height") > 200, "chart fills the right column")
win.close()

# --- audio mixer: the output / input switch swaps devices and volumes
win = env.scene("AudioMixerPanel {}", 520, 460)
QTest.qWait(150)
mixer = win.findChild(QQuickItem, "view")
devices = items(mixer, "audioDevice")
check([ev(d, "title") for d in devices] == ["Built-in Speakers", "LG UltraFine (HDMI)"], "output devices listed %s" % [ev(d, "title") for d in devices])
check([ev(d, "selected") for d in devices] == [True, False], "the default output is selected")
ev(devices[1], "clicked()")
check(ev(devices[1], "Audio.sink.name") == "speakers", "clicking a device asks Audio for the default (stub keeps it)")
check(len(items(mixer, "volumeSlider")) == 3, "device volume + one per app stream")
check(not ev(item(mixer, "mixerNoApps"), "visible"), "no empty state with app streams")
ev(item(mixer, "mixerInput"), "clicked()")
QTest.qWait(50)
check(ev(mixer, "showOutput") is False, "the input segment switches the mixer to input")
check([ev(d, "title") for d in items(mixer, "audioDevice")] == ["Built-in Microphone"], "input devices listed")
check(ev(item(mixer, "mixerNoApps"), "visible"), "empty state without input streams")
mute = item(mixer, "muteButton")
ev(mute, "clicked()")
check(ev(mute, "active") and ev(mute, "danger"), "mute shows the muted (danger) look")
win.close()

# --- EasyEffects: preset chips load presets, the switch bypasses
win = env.scene("EasyEffectsPanel {}", 520, 340)
QTest.qWait(150)
fx = win.findChild(QQuickItem, "view")
loud, night = item(fx, "preset_Loudness"), item(fx, "preset_Night")
check(ev(loud, "active") and not ev(night, "active"), "the loaded output preset is the active chip")
ev(night, "clicked()")
check(ev(night, "active") and not ev(loud, "active"), "a chip loads its preset")
ev(item(fx, "preset_Voice"), "clicked()")
check(ev(item(fx, "preset_Voice"), "active"), "input presets load too")
sw = item(fx, "panelSwitch")
check(ev(sw, "checked"), "effects on")
ev(sw, "flip()")
check(not ev(sw, "checked") and ev(night, "EasyEffectsService.bypassed"), "the switch bypasses the effects")
win.close()

# --- settings rows (Live Activities editor)
win = env.scene("""Column {
    property bool on: true; property string mode: "notch"; property int count: 4
    SettingsToggleRow { objectName: "toggle"; width: 300; label: "On"; checked: parent.on; onToggled: v => parent.on = v }
    SettingsSelectorRow { objectName: "selector"; width: 300; label: "Mode"; value: parent.mode
        options: [{ label: "Notch", value: "notch" }, { label: "Islands", value: "islands" }]
        onValueSelected: v => parent.mode = v }
    SettingsNumberRow { objectName: "number"; width: 300; label: "Max"; value: parent.count; minValue: 1; maxValue: 8
        onValueEdited: v => parent.count = v }
}""", 320, 200)
QTest.qWait(100)
rows = win.findChild(QQuickItem, "view")
ev(item(rows, "rowSwitch"), "flip()")
check(ev(rows, "on") is False and not ev(item(rows, "rowSwitch"), "checked"), "toggle row reports and follows the value")
sel = item(rows, "rowSelector")
check(ev(sel, "currentIndex") == 0, "selector shows the value")
ev(item(rows, "option_islands"), "clicked()")
check(ev(rows, "mode") == "islands" and ev(sel, "currentIndex") == 1, "selector picks a value")
field = item(rows, "numberField")
check(ev(field, "text") == "4", "number row shows the value")
ev(field, "text = '12'; editingFinished()")
check(ev(rows, "count") == 8, "out of range input is clamped to the maximum")
ev(field, "text = '6'; editingFinished()")
check(ev(rows, "count") == 6, "number row reports the edit")
win.close()

print("dashboard-tabs: ok")
h.exit(0)
