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

# ---- Launcher -----------------------------------------------------------------
select("launcher")
mini = item("launcherMini")
check(mini is not None, "launcher: the stage draws the launcher")
rows = lambda: h.eval(item("launcherStage"), "results.map(r => r.id).join(',')")  # noqa: E731
check("calculator" in rows(), "launcher: the calculator answers on the stage")
n = steps()
h.eval(item("launcherSearch:calculator"), "clicked()")
check("calculator" in ev("JSON.stringify(Config.prefix.launcher.disabled)") and steps() == n + 1,
      "launcher: a chip turns a provider off in one undo step")
check("calculator" not in rows(), "launcher: ...and its result leaves the stage")
ev("SettingsStore.undo()")
check("calculator" in rows(), "launcher: undo brings it back")
first = rows().split(",")[0]
h.eval(item(f"launcherMove:{first}:down"), "clicked()")
check(rows().split(",")[1] == first, "launcher: moving a provider down reorders the stage's results")
ev("SettingsStore.undo()")
h.eval(item("card:grid"), "clicked()")
check(ev("Config.layout.launcher.resultStyle") == "grid" and h.eval(item("launcherStage"), "grid") is True,
      "launcher: the Grid card draws a grid on the stage")
ev("SettingsStore.undo()")
h.eval(item("launcherMiniArea"), "clicked(null)")
check(wait_until(lambda: h.eval(shell, "currentCategory") == "layout"), "launcher: a click on it opens Where things open")

# ---- Dashboard ----------------------------------------------------------------
select("dashboard")
dstage = item("dashboardStage")
check(item("dashboardMini") is not None and item("dashboardHero") is not None,
      "dashboard: the stage draws the dashboard on its home view")
h.eval(item("dashboardTab:metrics"), "clicked()")
check(h.eval(dstage, "current") == "metrics", "dashboard: a click on a tab of the stage shows it")
n = steps()
h.eval(item("dashboardTabSwitch:metrics"), "toggled(false)")
check(steps() == n + 1 and item("dashboardTab:metrics") is None, "dashboard: hiding a tab is one step and leaves the rail")
check(h.eval(dstage, "current") == "widgets", "dashboard: ...and the stage falls back to the first tab")
ev("SettingsStore.undo()")
h.eval(item("dashboardTabMove:widgets:down"), "clicked()")
check(h.eval(dstage, "tabs.map(t => t.id).join(',')").startswith("wallpapers,widgets"),
      "dashboard: moving a tab reorders the stage's rail")
ev("SettingsStore.undo()")
h.eval(item("card:bento"), "clicked()")
check(ev("Config.layout.dashboard.home") == "bento", "dashboard: the Widget grid card switches the home view")
check(item("settingsSection:home") is not None, "dashboard: the home card is in the row")
ev("SettingsStore.undo()")

# ---- Widgets: desktop ---------------------------------------------------------
select("desktop")
check(item("desktopStage") is not None, "desktop: the stage is the desktop")
check(item("desktopWidgetMini:media") is None, "desktop: no widget yet")
n = steps()
h.eval(item("desktopWidget:media"), "clicked()")
check(steps() == n + 1 and ev("Config.desktop.widgets.length") == 1, "desktop: a widget chip adds one in one step")
check(wait_until(lambda: item("desktopWidgetMini:media") is not None), "desktop: ...and it shows on the stage at once")
h.eval(item("desktopWidget:media"), "clicked()")
check(ev("Config.desktop.widgets.length") == 0, "desktop: a second click takes it away")
ev("SettingsStore.undo()")
ev("SettingsStore.undo()")
check(ev("Config.desktop.widgets.length") == 0, "desktop: undo goes back to no widget")
check(item("desktopIcons") is not None and h.eval(item("desktopIcons"), "visible") is False, "desktop: icons off, none drawn")
ev("SettingsStore.set('desktop.enabled', true)")
check(h.eval(item("desktopIcons"), "visible") is True, "desktop: turning icons on draws them")
ev("SettingsStore.set('desktop.depthClock', true)")
QTest.qWait(100)
zone = item("desktopClockZoneArea")
check(zone is not None and h.eval(item("desktopClockZone"), "side") == "left", "desktop: with the clock on, the other side is a target")
n = steps()
h.eval(zone, "clicked(null)")
check(ev("Config.desktop.depthClockPosition") == "left" and steps() == n + 1, "desktop: a click moves the clock there in one step")
ev("SettingsStore.set('desktop.depthClock', false)")
ev("SettingsStore.set('desktop.enabled', false)")

# ---- Widgets: overview --------------------------------------------------------
select("overview")
check(wait_until(lambda: item("overviewWorkspace:10") is not None), "overview: 2 x 5 workspaces by default")
h.eval(item("overviewMore:columns"), "clicked()")
check(ev("Config.overview.columns") == 6 and item("overviewWorkspace:12") is not None, "overview: + adds a column on the stage")
h.eval(item("overviewLess:rows"), "clicked()")
check(ev("Config.overview.rows") == 1 and item("overviewWorkspace:7") is None, "overview: - removes a row")
ev("SettingsStore.undo()")
ev("SettingsStore.undo()")
h.eval(item("card:strip"), "clicked()")
check(ev("Config.overview.style") == "strip" and h.eval(item("overviewStage"), "rows") == 1, "overview: the strip is one row")
ev("SettingsStore.undo()")

# ---- Terminal -----------------------------------------------------------------
ev("TerminalLookService.presets = [{id: 'plain', name: 'Plain'}, {id: 'sakura-powerline', name: 'Sakura'}]")
ev("TerminalLookService.fetchPresets = [{id: 'sakura', name: 'Sakura'}]")
select("terminal")
check(wait_until(lambda: h.eval(item("terminalWindow"), "status === Loader.Ready")), "terminal: the stage is the terminal window")
check(item("promptCard:plain") is not None and item("promptCard:sakura-powerline") is not None,
      "terminal: a picture per prompt")
notice = item("terminalNotice")
check(h.eval(notice, "visible") is True, "terminal: with the prompt off the stage says so")
h.eval(notice, "clicked()")
check(ev("Config.terminal.enabled") is True and h.eval(notice, "visible") is False, "terminal: ...and a click turns it on")
ev("SettingsStore.undo()")
n = steps()
h.eval(item("greeting:sakura"), "clicked()")
check(ev("Config.terminal.greeting") == "fastfetch" and ev("Config.terminal.fastfetchPreset") == "sakura" and steps() == n + 1,
      "terminal: a greeting look turns the greeting on in one step")
check(h.eval(item("terminalWindow"), "item.greeting") is True, "terminal: the stage's terminal greets")
h.eval(item("greeting:off"), "clicked()")
check(ev("Config.terminal.greeting") == "none", "terminal: Off turns it off")

if failures:
    print(f"{len(failures)} failure(s)", file=sys.stderr)
h.exit(1 if failures else 0)
