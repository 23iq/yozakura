"""The personal destinations of the settings window, offscreen: their
stages react to the config and act on it (modules/settings/AGENTS.md, PAGE
COMPOSITION).

* Wallpaper: the film strip beside the stage lists the library and a
  click sets the wallpaper; the Fit cards switch to panorama in one undo
  step and the stage shows the panorama strip; the palette chip opens
  Look's palette.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402
from waits import wait_until  # noqa: E402

WALL_DIR = Path(__file__).resolve().parent.parent / "assets/wallpapers_example"
WALLS = [str(WALL_DIR / f"wallpaper-0{i}.png") for i in (1, 2, 3)]
env = SettingsEnv("settings-personal", wallpaper={"dir": str(WALL_DIR), "paths": WALLS, "current": WALLS[0]})
h = env.h
failures: list[str] = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1180; height: 780; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (!item) return null;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && kids.indexOf(item.contentItem) === -1) kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function onPage(name) { return findItem(name, findItem("settingsPage").item) }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr):
    return h.eval(win, expr)


def select(cat):
    h.eval(shell, f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")
    QTest.qWait(200)


def item(name):
    return ev(f'onPage("{name}")')


def steps():
    return ev("SettingsStore.undoStack.length")


# ---- Wallpaper ----------------------------------------------------------------
select("wallpapers")
check(item("wallpaperStage") is not None, "wallpaper: the stage is the screen with the wallpaper")
strip = item("wallpaperStrip")
check(strip is not None and wait_until(lambda: h.eval(strip, "count") == len(WALLS)),
      "wallpaper: the film strip lists the library")
b = item("wallpaper:wallpaper-02.png")
check(b is not None, "wallpaper: a thumbnail per picture")
h.eval(b, "clicked()")
check(ev("GlobalStates.wallpaperManager.currentWallpaper") == WALLS[1], "wallpaper: a click on a thumbnail sets it")
check(h.eval(item("wallpaper:wallpaper-02.png"), "selected") is True, "wallpaper: ...and rings it")
n = steps()
h.eval(item("card:panorama"), "clicked()")
check(ev("Config.desktop.wallpaperMode") == "panorama" and steps() == n + 1, "wallpaper: Panorama is one undo step")
check(wait_until(lambda: h.eval(item("wallpaperPanoramaStrip"), "opacity") > 0.99),
      "wallpaper: the stage shows the panorama strip")
ev("SettingsStore.undo()")
check(ev("Config.desktop.wallpaperMode") == "fill", "wallpaper: undo goes back to Fill")
h.eval(item("wallpaperSchemeLink"), "clicked()")
check(wait_until(lambda: h.eval(shell, "currentCategory") == "appearance"), "wallpaper: the palette chip opens Look")

if failures:
    print(f"{len(failures)} failure(s)", file=sys.stderr)
h.exit(1 if failures else 0)
