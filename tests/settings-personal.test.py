"""The personal destinations of the settings window, offscreen: their
stages react to the config and act on it (modules/settings/AGENTS.md, PAGE
COMPOSITION).

* Wallpaper: the film strip beside the stage lists the library and a
  click sets the wallpaper; the Fit cards switch to panorama in one undo
  step and the stage shows the panorama strip; the palette chip opens
  Look's palette.
* Launcher, Dashboard, Overview: plain pages (no desktop stage), Opens in
  on the page, provider chips and tab switches one undo step each.
* Widgets: a widget chip puts one on the stage's desktop (one step), icons
  and the depth clock's "move here" side.
* Terminal: the kitty window, a picture per prompt, the "off" chip turns
  the prompt on, a greeting look turns the greeting on in one step.
* Presets: the active preset on the stage and ringed in the strip, a click
  shows another, Browse opens every preset and part.
* Extras / Mods: the list form (a band over tall cards).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import Qt  # noqa: E402
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
    // the page's items, or the Screen canvas the host keeps for it
    function onPage(name) {
        var host = findItem("settingsPage");
        var shared = host.item && host.item.usesShared ? findItem(name, findItem("sharedCanvas")) : null;
        return shared || findItem(name, host.item);
    }
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
# the library: a grid beside the stage on a wide page, else a strip under it
grid = item("wallpaperGrid")
strip = grid if grid is not None and h.eval(grid, "visible") else item("wallpaperStrip")
check(strip is not None and wait_until(lambda: h.eval(strip, "count") == len(WALLS)),
      "wallpaper: the library lists every picture")
b = item("wallpaper:wallpaper-02.png")
check(b is not None, "wallpaper: a thumbnail per picture")
h.eval(b, "clicked()")
check(ev("GlobalStates.wallpaperManager.currentWallpaper") == WALLS[1], "wallpaper: a click on a thumbnail sets it")
check(h.eval(item("wallpaper:wallpaper-02.png"), "selected") is True, "wallpaper: ...and rings it")
# one Tab stop (the wallpaper on screen), arrows between pictures, Space sets
check([h.eval(item(f"wallpaper:wallpaper-0{i}.png"), "activeFocusOnTab") for i in (1, 2, 3)] == [False, True, False],
      "wallpaper: the library is one Tab stop, on the wallpaper on screen")
check(h.eval(item("wallpaper:wallpaper-02.png"), "Accessible.name") == "wallpaper-02.png", "wallpaper: a thumbnail is named")
h.eval(item("wallpaper:wallpaper-02.png"), "forceActiveFocus()")
QTest.keyClick(win, Qt.Key_Right)
check(h.eval(item("wallpaper:wallpaper-03.png"), "activeFocus") is True, "wallpaper: Right moves the focus to the next picture")
QTest.keyClick(win, Qt.Key_Space)
check(ev("GlobalStates.wallpaperManager.currentWallpaper") == WALLS[2], "wallpaper: ...Space sets it")
QTest.keyClick(win, Qt.Key_Home)
check(h.eval(item("wallpaper:wallpaper-01.png"), "activeFocus") is True, "wallpaper: Home goes to the first")
h.eval(item("wallpaper:wallpaper-02.png"), "clicked()")
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
check(wait_until(lambda: item("launcherLive") is not None and h.eval(item("launcherLive"), "ready") is True,
                 timeout_ms=10000), "launcher: the stage shows the real launcher")
# the real launcher's results (LauncherSearch.items): the live apps, sample rows
rows = lambda: h.eval(item("launcherLive"), "find('launcherSearch').items.map(r => r.provider).join(',')")  # noqa: E731
check(wait_until(lambda: "apps" in rows() and "calculator" in rows()),
      "launcher: it answers with your apps and a sample row per provider")
check(h.eval(item("launcherLive"), "find('launcherSearch').searchText") != "", "launcher: a sample query is typed")
check(item("settingRow:layout.launcher.host") is not None, "launcher: Opens in is on the page")
n = steps()
h.eval(item("launcherSearch:calculator"), "toggled(false)")
check("calculator" in ev("JSON.stringify(Config.prefix.launcher.disabled)") and steps() == n + 1,
      "launcher: a switch turns a provider off in one undo step")
ev("SettingsStore.undo()")
check("calculator" not in ev("JSON.stringify(Config.prefix.launcher.disabled)") and wait_until(lambda: "calculator" in rows()),
      "launcher: undo brings it back, on the stage too")
check(wait_until(lambda: item("card:grid") is not None), "launcher: a picture per result style")
if item("card:grid") is not None:
    h.eval(item("card:grid"), "clicked()")
check(ev("Config.layout.launcher.resultStyle") == "grid", "launcher: the Grid card picks the grid")
ev("SettingsStore.undo()")

# ---- Dashboard ----------------------------------------------------------------
select("dashboard")
check(wait_until(lambda: item("dashboardLive") is not None and h.eval(item("dashboardLive"), "ready") is True,
                 timeout_ms=10000), "dashboard: the stage shows the real dashboard")
check(h.eval(item("dashboardLive"), "find('header') !== null && find('hero') !== null"),
      "dashboard: its header and the stage home's hero are the real ones")
check(item("settingRow:layout.dashboard.host") is not None, "dashboard: Opens in is on the page")
n = steps()
check(wait_until(lambda: item("dashboardTabSwitch:metrics") is not None), "dashboardTabSwitch:metrics" + " exists")
h.eval(item("dashboardTabSwitch:metrics"), "toggled(false)")
check(steps() == n + 1, "dashboard: hiding a tab is one step")
ev("SettingsStore.undo()")
check(wait_until(lambda: item("card:bento") is not None), "card:bento" + " exists")
h.eval(item("card:bento"), "clicked()")
check(ev("Config.layout.dashboard.home") == "bento", "dashboard: the Widget grid card switches the home view")
check(item("settingsSection:home") is not None, "dashboard: the home card is on the page")
ev("SettingsStore.undo()")

# ---- Widgets: desktop ---------------------------------------------------------
select("desktop")
check(item("desktopStage") is not None, "desktop: the stage is the desktop")
check(item("desktopWidgetMini:media") is None, "desktop: no widget yet")
n = steps()
check(item("desktopWidget:media") is None, "desktop: no second list of widget chips")
check(wait_until(lambda: item("addWidget:media") is not None), "desktop: the widgets card adds a widget")
h.eval(item("addWidget:media"), "clicked()")
check(steps() == n + 1 and ev("Config.desktop.widgets.length") == 1, "desktop: adding a widget is one step")
check(wait_until(lambda: item("desktopWidgetMini:media") is not None), "desktop: ...and it shows on the stage at once")
ev("SettingsStore.undo()")
check(ev("Config.desktop.widgets.length") == 0, "desktop: undo goes back to no widget")
check(item("desktopIcons") is not None and h.eval(item("desktopIcons"), "visible") is False, "desktop: icons off, none drawn")
ev("SettingsStore.set('desktop.enabled', true)")
check(h.eval(item("desktopIcons"), "visible") is True, "desktop: turning icons on draws them")
ev("SettingsStore.set('desktop.depthClock', true)")
QTest.qWait(100)
zone = item("desktopClockZoneArea")
stage = item("desktopStage")
# the clock is drawn where its real layout put it; the target is the other side
check(wait_until(lambda: h.eval(item("desktopClock"), "status") == 1), "desktop: the clock is drawn on the stage")
drawn = h.eval(stage, "clockSide")
target = h.eval(item("desktopClockZone"), "side")
check(zone is not None and target in ("left", "right") and target != drawn,
      f"desktop: with the clock on, the other side is a target (drawn {drawn}, target {target})")
n = steps()
h.eval(zone, "clicked(null)")
check(ev("Config.desktop.depthClockPosition") == target and steps() == n + 1, "desktop: a click moves the clock there in one step")
check(wait_until(lambda: h.eval(stage, "clockSide") == target), "desktop: ...and it is drawn there")
check(h.eval(item("desktopClockZone"), "side") == drawn, "desktop: the target moves to the side it left")
ev("SettingsStore.set('desktop.depthClock', false)")
ev("SettingsStore.set('desktop.enabled', false)")

# ---- Widgets: overview --------------------------------------------------------
select("overview")
check(item("pageStage") is None or h.eval(item("pageStage"), "active") is False, "overview: no stage")
for e in ("overview.rows", "overview.columns", "overview.style"):
    check(item(f"settingRow:{e}") is not None, f"overview: {e} is a row")
check(wait_until(lambda: item("card:strip") is not None), "card:strip" + " exists")
h.eval(item("card:strip"), "clicked()")
check(ev("Config.overview.style") == "strip", "overview: the strip card picks the strip")
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

# ---- Presets ------------------------------------------------------------------
PRESETS = ('[{name: "Hanami", official: true, active: true, tags: ["dark"], look: {"bar.position": "top"}},'
           ' {name: "Kaze", official: true, active: false, tags: ["light"], look: {"bar.position": "bottom", "theme.lightMode": true}}]')
select("presets")
# the list failed to load (no backend): an error with Retry, never a blank
# card and a nameless disabled Apply
ev('PresetStudio.presets = []; PresetStudio.loading = false; PresetStudio.error = "backend unavailable"')
QTest.qWait(100)
check(item("presetStripEmpty") is not None and h.eval(item("presetStripEmpty"), "visible") is True
      and item("presetRetry") is not None and h.eval(item("presetRetry"), "visible") is True,
      "presets: a list that failed to load says so and offers Retry")
check(h.eval(item("presetApply"), "visible") is False, "presets: ...with no Apply for no preset")
ev('PresetStudio.error = ""')
ev(f"PresetStudio.presets = {PRESETS}")
QTest.qWait(100)
check(h.eval(item("presetStripEmpty"), "visible") is False and h.eval(item("presetStripLoading"), "visible") is False,
      "presets: with the list, the strip shows the presets")
check(h.eval(item("presetStrip"), "contentWidth") > 0 and item("presetPick:Kaze") is not None,
      "presets: the strip has a card per preset")
check(item("pageStage") is not None and item("presetStageShell") is not None, "presets: the stage is the preset's miniature")
check(item("presetName") is not None and h.eval(item("presetName"), "text") == "Hanami", "presets: the active preset is on the stage")
check(h.eval(item("presetPick:Hanami"), "selected") is True, "presets: the strip rings the active preset")
check(h.eval(item("presetApply"), "enabled") is False, "presets: the active one cannot be applied again")
h.eval(item("presetPick:Kaze"), "clicked()")
check(h.eval(item("presetName"), "text") == "Kaze" and h.eval(item("presetStageShell"), "edge") == "bottom",
      "presets: a click on a preset shows it on the stage")
check(h.eval(item("presetApply"), "enabled") is True, "presets: ...and offers to apply it")
check(item("presetsAutoSave") is not None, "presets: the studio's setting is in the info panel")
# Browse lives in the info panel's ⋯ menu (with Mixer and Import)
check(item("presetMore") is not None, "presets: the rarer studio actions sit behind a ⋯ button")
h.eval(item("presetSide"), "browseRequested()")
check(h.eval(ev('findItem("settingsPage").item'), "view") == "browse", "presets: Browse opens every preset and part")

# ---- Extras / Mods: the list form ---------------------------------------------
ev("ExtrasService.catalog = {categories: [], entries: [{id: 'a', name: 'A', category: 'x', icon: 'globe'},"
   " {id: 'b', name: 'B', category: 'x', icon: 'globe'}, {id: 'c', name: 'C', category: 'x', icon: 'globe'}]}")
ev("ExtrasService.status = {a: {id: 'a', state: 'installed'}, b: {id: 'b', state: 'missing'}}")
select("extras")
page = ev('findItem("settingsPage").item')
check(h.eval(page, "listForm") is True and item("pageStage") is not None, "extras: a band over the catalog card")
check(h.eval(item("extrasRing"), "Math.round(value * 3)") == 1, "extras: the band's ring shows how much is installed")
check(item("catalogGrid") is not None, "extras: the catalog lives in the tall card")
ev("ModsService.mods = [{id: 'm1', name: 'M1', enabled: true, valid: true, compatible: true},"
   " {id: 'm2', name: 'M2', enabled: false, valid: true, compatible: true}]")
select("mods")
check(h.eval(ev('findItem("settingsPage").item'), "onCount") == 1, "mods: the band counts the mods that are on")
check(item("modsList") is not None and item("modsDetails") is not None, "mods: the list and the selected mod side by side")

if failures:
    print(f"{len(failures)} failure(s)", file=sys.stderr)
h.exit(1 if failures else 0)
