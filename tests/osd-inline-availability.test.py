"""Real controls and service fall back per screen when their bar host is hidden."""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from panels_env import PanelsEnv  # noqa: E402
from panels_stubs import COMPOSITOR_DATA  # noqa: E402
from qmlharness import REPO  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = PanelsEnv("osd-inline-availability", bar={
    "pinnedOnStartup": False, "frameEnabled": False, "containBar": False,
    "layout": {"style": "classic", "left": [], "right": ["controls"], "drawer": []},
}, extra={"layout": {"osd": {"style": "bar-inline"}}})
h = env.h
h.singleton("qs.modules.bar.workspaces", "CompositorData", COMPOSITOR_DATA.replace(
    "function monitorHasFullscreen(m) { return false; }",
    "property bool fullscreen: false; function monitorHasFullscreen(m) { return fullscreen; }"))
shutil.copytree(REPO / "modules/shell/osd", env.root / "qs/modules/shell/osd", dirs_exist_ok=True)
env._qmldir(env.root / "qs/modules/shell/osd", "qs.modules.shell.osd")
env._qmldir(env.root / "qs/modules/shell/osd/styles", "qs.modules.shell.osd.styles")
h.singleton("qs.modules.services", "Audio", """QtObject {
    property QtObject sink: QtObject { property bool ready: true; property string description: "Speakers"
        property QtObject audio: QtObject { property real volume: 0.4; property bool muted: false } }
    property QtObject source: null
    signal volumeChanged(real volume, bool muted, var node)
    signal micVolumeChanged(real volume, bool muted, var node)
    function volumeIcon(v, muted) { return "" }
    function setVolume(v) { sink.audio.volume = v }
    function setMicVolume(v) {}
}""")
h.singleton("qs.modules.services", "Brightness", """QtObject {
    property bool syncBrightness: false
    signal brightnessChanged(real value, var screen)
    function getMonitorForScreen(s) { return null }
}""")
h.singleton("qs.modules.services", "OsdService", (REPO / "modules/services/OsdService.qml").read_text())
window = env.scene(1920, 1080, windows=False)
QTest.qWait(80)


def controls(item):
    found = [item] if item.objectName() == "controlsModule" else []
    for child in item.childItems():
        found.extend(controls(child))
    return found


hosts = controls(window.contentItem())
assert len(hosts) == 1, len(hosts)
bar = hosts[0].property("bar")
inline = next(child for child in hosts[0].findChildren(type(hosts[0])) if "OsdBarInline" in child.metaObject().className())
svc = h.engine.singletonInstance("qs.modules.services", "OsdService")
assert not h.eval(bar, "reveal")
assert h.eval(svc, "route.window"), "a hidden unpinned bar must not suppress the OSD window"
h.eval(svc, 'report("volume", 0.2, false, "", "")')
assert not inline.property("shown")
h.eval(bar, "hoverActive = true")
QTest.qWait(80)
assert h.eval(svc, 'routeForScreen("DP-1").window') is False
assert h.eval(svc, 'routeForScreen("DP-2").window') is True, "another screen has no inline host"
assert svc.property("inlineHosts") == 1, svc.property("inlineHosts")
h.eval(svc, 'report("volume", 0.3, false, "", "")')
assert inline.property("shown")
assert inline.property("value") == 0.3
compositor = h.engine.singletonInstance("qs.modules.bar.workspaces", "CompositorData")
compositor.setProperty("fullscreen", True)
assert not h.eval(bar, "reveal")
assert h.eval(svc, 'routeForScreen("DP-1").window'), "fullscreen-hidden bar must fall back"
compositor.setProperty("fullscreen", False)
h.eval(window, 'Config.bar.layout = ({style: "classic", left: [], right: [], drawer: ["controls"]})')
QTest.qWait(100)
assert svc.property("inlineHosts") == 0, "collapsed drawer cannot host an OSD"
bar = controls(window.contentItem())[0].property("bar")
h.eval(bar, "hoverActive = true; drawerHovered = true; drawerExpanded = true")
QTest.qWait(500)
assert svc.property("inlineHosts") == 1
h.eval(bar, "drawerHovered = false; drawerExpanded = false; hoverActive = false")
QTest.qWait(500)
assert svc.property("inlineHosts") == 0
assert h.eval(svc, 'routeForScreen("DP-1").window')
h.exit(0)
