"""The settings window opens and changes pages without layout jumps, offscreen.

Traces geometry on every rendered frame (QQuickWindow.frameSwapped) while the
window content is created asynchronously (as KeepAliveLoader does) and while
pages switch, and checks what the user sees:

* A plain open shows home with its tiles in place from the first frame and
  builds no page behind it; the tiles do not move while the window opens.
* A deep link (a page asked for at open) shows that page at once, without
  passing through home.
* A page stays hidden until the sections on screen are built (SettingsPage
  fills its sections a few per frame), then enters: once any of it is
  visible, no section or row inside the viewport appears or moves (in page
  coordinates; the enter slide is a transform of the host).
* A narrow window reflows the home bento to fewer columns.
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
        var s = { "rows": {}, "tiles": {} };
        var home = findItem("settingsHome");
        s.home = home && home.visible ? home.opacity : 0;
        walk(home, x => {
            var n = String(x.objectName);
            if (n.indexOf("homeTile:") === 0 && x.visible) {
                var p = x.mapToItem(home, 0, 0);
                s.tiles[n] = [Math.round(p.x), Math.round(p.y), Math.round(x.width), Math.round(x.height)];
            }
        });
        var view = findItem("settingsPageView");
        var page = findItem("settingsPage");
        s.opacity = page && view && view.visible ? page.opacity * view.opacity : 0;
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


# Open at home: the content is created asynchronously, as the shell's
# KeepAliveLoader does; the tiles are in place from the first frame.
h.eval(win, 'GlobalStates.settingsCategory = ""')
frames = record(lambda: h.eval(win, "ld.active = true"), 1200)
check(len(frames) > 5, "open: frames were rendered")
homes = [f for f in frames if f["home"] > 0]
check(len(homes) > 0 and len(homes[0]["tiles"]) == 9, "open: home shows its tiles in its first frame")
check(all(f["tiles"] == homes[0]["tiles"] for f in homes), "open: the home tiles do not move")
check(all(f["opacity"] == 0 for f in frames), "open: no page is built behind home")

shell = h.find(win, "shell")
for cat in ("appearance", "wallpapers", "system", "desktop", "notch", "bar"):
    # (a long page under a loaded machine can take most of a second to show)
    frames = record(lambda cat=cat: h.eval(shell, f'select("{cat}")'), 1500)
    rows_stable(f"switch to {cat}", frames)
    check(
        wait_until(lambda: h.eval(win, 'findItem("settingsPage").opacity * findItem("settingsPageView").opacity') == 1),
        f"{cat}: the page ends fully shown",
    )

# Deep link: a fresh open on a page shows it at once, never home.
h.eval(win, "ld.active = false")
pump(60)
h.eval(win, 'GlobalStates.settingsCategory = "appearance"')
frames = record(lambda: h.eval(win, "ld.active = true"), 1200)
check(all(f["home"] == 0 for f in frames), "deep link: home is never shown")
rows_stable("deep link appearance", frames)
shell = h.find(win, "shell")

# Back home, then a narrow window: the bento reflows to fewer columns.
h.eval(shell, "goHome()")
check(wait_until(lambda: h.eval(win, 'findItem("settingsHome").opacity') == 1), "back: home fully shown")
wide = h.eval(win, 'findItem("settingsHome").columns')
win.setWidth(700)
pump(60)
narrow = h.eval(win, 'findItem("settingsHome").columns')
check(narrow < wide, f"narrow window: fewer home columns ({wide} -> {narrow})")

if failures:
    h.exit(1)
print("ok")
h.exit(0)
