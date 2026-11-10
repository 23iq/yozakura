"""The settings window opens and changes pages without layout jumps, offscreen.

Traces geometry on every rendered frame (QQuickWindow.frameSwapped) while the
window content is created asynchronously (as KeepAliveLoader does) and while
pages switch, and checks what the user sees:

* The sidebar has its final width from the first frame: it used to start as
  the 76 px rail (the shell is 0 wide when it completes) and grow to 264 px
  over the page through a width Behavior, sliding the whole page sideways.
* The sidebar rows do not move while the window opens.
* A page stays hidden until the sections on screen are built (SettingsPage
  fills its sections a few per frame), then enters: once any of it is
  visible, no section or row inside the viewport appears or moves (in page
  coordinates; the enter slide is a transform of the host).
* A narrow window shows the rail at once (no animation from the width), and
  the compact search sidebar still slides out.
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

# Frames are sampled on frameSwapped: the GUI thread must render them.
os.environ["QSG_RENDER_LOOP"] = "basic"
headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from settings_env import SettingsEnv  # noqa: E402
from waits import pump, wait_until  # noqa: E402

env = SettingsEnv("settings-load-stable")
h = env.h
failures: list[str] = []


def check(cond: bool, what: str) -> None:
    if not cond:
        failures.append(what)
        print("FAIL:", what, file=sys.stderr)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.globals
Window {
    id: w
    width: 1180; height: 780; visible: true
    property var log: []
    property bool recording: false
    function walk(item, fn) {
        if (!item) return;
        fn(item);
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) walk(kids[i], fn);
    }
    function findItem(name) {
        var found = null;
        walk(w.contentItem, x => { if (!found && x.objectName === name) found = x; });
        return found;
    }
    function shown(it) {
        for (var x = it; x; x = x.parent) if (!x.visible || x.opacity === 0) return false;
        return true;
    }
    function sample() {
        var s = { "rows": {}, "nav": {} };
        var bar = findItem("settingsSidebar");
        s.sidebar = bar ? bar.width : -1;
        walk(bar, x => {
            var n = String(x.objectName);
            if (n.indexOf("navGroup:") === 0)
                s.nav[n] = Math.round(x.mapToItem(bar, 0, 0).y);
        });
        var page = findItem("settingsPage");
        s.opacity = page ? page.opacity : 0;
        if (page && page.item) {
            walk(page.item, x => {
                var n = String(x.objectName);
                if ((n.indexOf("settingRow:") !== 0 && n.indexOf("settingsSection:") !== 0) || !shown(x))
                    return;
                var p = x.mapToItem(page, 0, 0);
                if (p.y < page.height)
                    s.rows[n] = [Math.round(p.x), Math.round(p.y), Math.round(x.width), Math.round(x.height)];
            });
        }
        log.push(s);
    }
    onFrameSwapped: if (recording) sample()
    Loader {
        id: ld
        objectName: "ld"
        anchors.fill: parent
        active: false
        asynchronous: true
        sourceComponent: SettingsShell { objectName: "shell" }
    }
}""")


def record(action, ms: int = 700) -> list[dict]:
    h.eval(win, "log = []; recording = true")
    action()
    pump(ms)
    h.eval(win, "recording = false")
    return json.loads(h.eval(win, "JSON.stringify(log)"))


def rows_stable(label: str, frames: list[dict]) -> None:
    visible = [f for f in frames if f["opacity"] > 0]
    check(len(visible) > 0, f"{label}: the page is shown")
    if not visible:
        return
    first = visible[0]["rows"]
    check(len(first) > 0, f"{label}: rows on screen in the first visible frame")
    for i, f in enumerate(visible[1:], 1):
        for name, geo in f["rows"].items():
            was = first.get(name)
            if was is None:
                check(False, f"{label}: {name} popped in {i} frame(s) after the page showed")
                return
            if was != geo:
                check(False, f"{label}: {name} moved {was} -> {geo} {i} frame(s) after the page showed")
                return


# Open: the content is created asynchronously, as the shell's KeepAliveLoader does.
h.eval(win, 'GlobalStates.settingsCategory = "appearance"')
frames = record(lambda: h.eval(win, "ld.active = true"), 1200)
check(len(frames) > 5, "open: frames were rendered")
widths = sorted({f["sidebar"] for f in frames if f["sidebar"] >= 0})
check(widths == [264], f"open: the sidebar is 264 px from the first frame (saw {widths})")
navs = [f["nav"] for f in frames if f["nav"]]
check(all(n == navs[0] for n in navs), "open: the sidebar rows do not move")
rows_stable("open appearance", frames)

shell = h.find(win, "shell")
for cat in ("wallpapers", "system", "desktop", "notch", "bar"):
    frames = record(lambda cat=cat: h.eval(shell, f'select("{cat}")'))
    rows_stable(f"switch to {cat}", frames)
    check(wait_until(lambda: h.eval(win, 'findItem("settingsPage").opacity') == 1), f"{cat}: the page ends fully shown")

# Narrow window: the rail at once (no width animation), the search slides out.
win.setWidth(800)
pump(40)
check(h.eval(win, 'findItem("settingsSidebar").width') == 76, "narrow window: the rail at once")
h.eval(shell, "openSearch()")
pump(40)
mid = h.eval(win, 'findItem("settingsSidebar").width')
check(wait_until(lambda: h.eval(win, 'findItem("settingsSidebar").width') == 264), "compact search: full sidebar")
check(76 <= mid <= 264, f"compact search: the sidebar slides out ({mid})")
h.eval(shell, "searchOpen = false")
check(wait_until(lambda: h.eval(win, 'findItem("settingsSidebar").width') == 76), "compact search closed: rail")

if failures:
    h.exit(1)
print("ok")
h.exit(0)
