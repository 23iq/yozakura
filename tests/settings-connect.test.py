"""The connect pages (Network, Bluetooth, Sound), offscreen with the device
fixtures (tests/lib/device_fixtures.py).

* Network: the band names the connected network; a row of the list picks a
  network for the details card; Connect / Disconnect and the Wi-Fi tile
  call NetworkService.
* Bluetooth: the band lists the connected devices; picking a paired one
  offers Connect, a new one Pair; Forget removes it.
* Sound (when present): the volume sliders and device rows call Audio.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("settings-connect", devices=True)
h = env.h
failures: list[str] = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1180; height: 780; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && kids.indexOf(item.contentItem) === -1) kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function page() { var host = findItem("settingsPage"); return host ? host.item : null }
    function find(name) { return findItem(name, page()) }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr):
    return h.eval(win, expr)


def calls(svc):
    return json.loads(ev(f"JSON.stringify({svc}.calls)"))


def open_page(cat):
    h.eval(shell, f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")
    QTest.qWait(250)


# ---- Network
open_page("network")
check(ev('w.find("networkName").text') == "Sakura 5G", "the band names the connected network")
check(ev('w.find("wifiAction").text') == "Disconnect", "the connected one is shown first, with Disconnect")
# the action sits under the facts, never over the last one
check(ev('(function(){ var a = w.find("wifiAction"), d = w.find("wifiDetails"); return a.y >= d.children[1].y + d.children[1].height; })()') is True,
      "Disconnect sits under the facts")
h.eval(ev('w.find("deviceRow:Café Hanami")'), "children[children.length - 1].clicked(null)")
QTest.qWait(50)
check(ev('w.find("wifiDetails").ap.ssid') == "Café Hanami", "a row picks the network for the details card")
h.eval(ev('w.find("wifiAction")'), "clicked()")
check(["connect", "Café Hanami"] in calls("NetworkService"), "Connect asks NetworkService to connect")
h.eval(ev('w.find("wifiTile")'), "clicked()")
check(ev("NetworkService.wifiEnabled") is False, "the band's tile turns Wi-Fi off")
ev("NetworkService.wifiEnabled = true")

# ---- Bluetooth
open_page("bluetooth")
check(ev('w.find("bluetoothState").text') == "2 connected", "the band counts the connected devices")
h.eval(ev('w.find("deviceRow:F4:73:35:77:88:99")'), "children[children.length - 1].clicked(null)")
QTest.qWait(50)
check(ev('w.find("btAction").text') == "Connect", "a paired device offers Connect")
h.eval(ev('w.find("btAction")'), "clicked()")
check(["connect", "F4:73:35:77:88:99"] in calls("BluetoothService"), "...which connects it")
h.eval(ev('w.find("deviceRow:08:EB:ED:AA:BB:CC")'), "children[children.length - 1].clicked(null)")
QTest.qWait(50)
check(ev('w.find("btAction").text') == "Pair" and ev('w.find("btForget").visible') is False, "a new device offers Pair, nothing to forget")

# ---- Sound
open_page("sound")
slider = ev('w.find("soundOutputSlider")')
check(abs(h.eval(slider, "value") - 0.62) < 0.001, "the band's output slider shows the volume")
check(h.eval(slider, "level") > 0, "...with a live meter while shown")
check(ev("CavaService.consumers.settingsSound") is True, "the meter asks for the visualizer's levels only while shown")
h.eval(slider, "moved(0.4)")
check(["volume", 0.4] in calls("Audio"), "moving it sets the volume")
h.eval(ev('w.find("deviceRow:42")'), "children[children.length - 1].clicked(null)")
check(["sink", 42] in calls("Audio"), "a click on an output makes it the one in use")
check(ev('w.find("appVolumes") !== null') and ev('w.find("appVolume:Spotify") !== null'), "the apps playing have their own volume")

# ---- Effects
open_page("effects")
h.eval(ev('w.find("deviceRow:Podcast")'), "children[children.length - 1].clicked(null)")
check(ev("EasyEffectsService.activeOutputPreset") == "Podcast", "a click on a preset runs it")
h.eval(ev('w.find("effectsTile")'), "clicked()")
check(ev("EasyEffectsService.bypassed") is True, "the band's tile bypasses the effects")
h.eval(shell, 'select("network")')
env.wait_page(win)
QTest.qWait(100)
check(ev("CavaService.consumers.settingsSound") is False, "leaving Sound stops the meter")

if failures:
    print(f"settings-connect: {len(failures)} failure(s)")
    h.exit(1)
print("settings-connect: ok")
h.exit(0)
