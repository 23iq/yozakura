"""BatterySaver (modules/globals/BatterySaver.qml): the one "saver is active
right now" switch read by the visualizer, the media line and the wallpaper.

Active only while performance.batterySaver is on AND UPower's display device
is a battery AND the machine runs from it. Off by default; a desktop (no
battery device) is never affected; plugging in ends it at once.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness('battery-saver')
h.module('Quickshell', {'Singleton': 'QtObject { default property list<QtObject> data }'})
h.module('Quickshell.Services.UPower', {
    # As in Quickshell: the device has no enums of its own, the values live
    # on the UPowerDeviceType singleton.
    'UPowerDevice': 'QtObject { property int type: 0 }',
    'UPowerDeviceType': 'pragma Singleton\nQtObject { enum Enum { Unknown, LinePower, Battery } }',
    'UPower': '''pragma Singleton
QtObject {
    property bool onBattery: false
    property QtObject displayDevice: null
}''',
})
h.singleton('qs.config', 'Config', 'QtObject { property QtObject performance: QtObject { property bool batterySaver: false } }')
h.copy('modules/globals/BatterySaver.qml', strip_singleton=True)
root = h.load('''import QtQuick
import Quickshell.Services.UPower
Item {
    property alias saver: s
    property QtObject battery: UPowerDevice { type: 2 }
    property QtObject mains: UPowerDevice { type: 1 }
    BatterySaver { id: s }
}''', auto_stub=False)

upower = h.engine.singletonInstance('Quickshell.Services.UPower', 'UPower')
perf = h.engine.singletonInstance('qs.config', 'Config').property('performance')

ok_all = True


def check(name, ok):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name)


def active():
    return h.eval(root, 'saver.active')


upower.setProperty('displayDevice', root.property('battery'))
upower.setProperty('onBattery', True)
check('off by default, even on battery', active() is False)
check('UPower is not read while the saver is off', h.eval(root, 'saver.hasBattery') is False)

perf.setProperty('batterySaver', True)
check('on + laptop on battery = active', active() is True)
upower.setProperty('onBattery', False)
check('plugged in = inactive', active() is False)
upower.setProperty('onBattery', True)
check('unplugged again = active', active() is True)

upower.setProperty('displayDevice', root.property('mains'))
check('a desktop (display device is not a battery) is unaffected', active() is False)
upower.setProperty('displayDevice', None)
check('no UPower device is unaffected', active() is False)

upower.setProperty('displayDevice', root.property('battery'))
check('back on a battery', active() is True)
perf.setProperty('batterySaver', False)
check('turning the setting off ends it', active() is False)

print('BatterySaver:', 'PASS' if ok_all else 'FAIL')
sys.exit(0 if ok_all else 1)
