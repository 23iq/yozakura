"""Live previews of the island, the notifications, the OSD and the dock in
Settings (modules/settings/live, LIVE PREVIEWS in modules/settings/AGENTS.md),
offscreen.

* The Island stage is the shell's own island (shell/NotchPreview.qml: the
  real Notch and resting view) showing each state from its samples: at rest
  nothing plays, music shows the sample track, a notification grows the
  island with its card, a timer adds its activity segment; nothing of the
  session leaks in (no cava consumer, no visibilities).
* The Screen canvas draws the real island at rest at its place.
* The Notifications stage is a real corner toast (with the app's stack when
  grouped), the real island holding the message, or the real strips.
* Menus & OSD: the OSD style is the real component; "in the bar" is the real
  controls button holding the level, and a bar in a preview never registers
  an inline OSD host.
* The dock's indicator follows a preview's override (DockIndicator pick).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

import live_previews  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from settings_env import SettingsEnv  # noqa: E402
from waits import wait_until  # noqa: E402

env = SettingsEnv("settings-live-parts")
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
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.settings.live
Window {
    id: w
    width: 1400; height: 1000; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (!item) return null;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function count(name, from) {
        var item = from || w.contentItem, n = item.objectName === name ? 1 : 0;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) n += count(name, kids[i]);
        return n;
    }
    // the shown (visible) stage of that name
    function stage(name) {
        var found = null;
        (function walk(it) {
            if (found || !it) return;
            if (it.objectName === name && it.visible && it.width > 0) { found = it; return; }
            for (var i = 0; i < it.children.length; i++) walk(it.children[i]);
        })(w.contentItem);
        return found;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
    // a real dock with an indicator style the config does not have
    LiveDock {
        objectName: "lineDock"
        x: 0; y: 900; width: 400; height: 80
        overrides: ({ "dock.indicator": "line", "dock.showRunningIndicators": true })
    }
}""")
shell = h.find(win, "shell")


def ev(expr):
    return h.eval(win, expr)


def select(cat):
    h.eval(shell, f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")
    live_previews.wait_built(env)


# ---- the Island stage ---------------------------------------------------------
ev("SettingsStore.set('notch.position', 'top')")
select("notch")
st = ev('w.stage("islandStage")')
check(st is not None, "the Island stage shows")
live = ev('w.findItem("islandLive", w.stage("islandStage"))')
check(live is not None and wait_until(lambda: h.eval(live, "island !== null && ready")), "the stage builds the real island")
check(ev('w.findItem("islandHeader", w.stage("islandStage")) !== null'), "...the shell's own resting view (its header)")
rest_h = h.eval(live, "targetRect.height")
check(rest_h > 0, f"at rest it has its resting size ({rest_h})")


def resting_view():
    # the DefaultView is the Notch's stack root: found through the header's parent
    return ev('w.findItem("islandHeader", w.stage("islandStage")).parent')


check(h.eval(resting_view(), "activePlayer === null"), "at rest nothing plays (the session's player is not shown)")
h.eval(st, 'showing = "media"')
check(wait_until(lambda: h.eval(resting_view(), "activePlayer !== null && activePlayer.trackTitle === 'Hanami Night'")),
      "music: the sample track")
h.eval(st, 'showing = "notification"')
check(wait_until(lambda: h.eval(live, "targetRect.height") > rest_h + 40), "a notification grows the island")
check(wait_until(lambda: ev('w.findItem("islandNotifications", w.stage("islandStage")).visible') is True),
      "...with the notch's own notification view")
h.eval(st, 'showing = "timer"')
check(wait_until(lambda: h.eval(resting_view(), "hasActivities") is True), "a timer: its activity segment")
check(wait_until(lambda: abs(h.eval(live, "targetRect.height") - rest_h) < 1), "...and the island back at its resting depth")
check(ev("Object.keys(CavaService.consumers).filter(k => CavaService.consumers[k]).length") == 0,
      "no cava consumer registered by a preview")
part = ev('w.findItem("islandPart", w.stage("islandStage"))')
check(part is not None and h.eval(part, "width") > 0, "the island's place answers clicks (its card)")
h.eval(st, 'showing = "rest"')

# the Screen canvas: the real island at rest, at its place
canvas_live = ev('w.findItem("screenMiniLive", w.findItem("sharedCanvas"))')
check(canvas_live is not None and wait_until(lambda: h.eval(canvas_live, "islandOn") is True),
      "the Screen canvas draws the real island")
r = h.eval(canvas_live, "islandRect()")
check(r is not None and r.width() > 0 and r.y() < 40, "...on the top edge")
ev("SettingsStore.set('notch.position', 'left')")
check(wait_until(lambda: h.eval(canvas_live, "islandRect().x") < 80 and h.eval(canvas_live, "islandRect().height") > h.eval(canvas_live, "islandRect().width")),
      "...and upright on a side edge")
ev("SettingsStore.set('notch.position', 'top')")

# ---- the Notifications stage --------------------------------------------------
ev("SettingsStore.set('notifications.presentation', 'corner')")
ev("SettingsStore.set('notifications.groupByApp', true)")
select("notifications")
check(wait_until(lambda: ev('w.findItem("toastCard", w.stage("notifStage")) !== null')), "corner: the real toast card")
check(wait_until(lambda: ev('w.count("toastSheet", w.stage("notifStage"))') == 2), "...grouped: the app's other two behind it")
ev("SettingsStore.set('notifications.presentation', 'notch')")
check(wait_until(lambda: ev('w.findItem("islandNotifications", w.findItem("notifIsland", w.stage("notifStage"))) !== null')),
      "island: the real island holding the message")
ev("SettingsStore.set('notifications.presentation', 'strips')")
check(wait_until(lambda: ev('w.findItem("stripsList", w.stage("notifStage")) !== null && w.findItem("stripsList", w.stage("notifStage")).count === 2')),
      "strips: the real strips, one per sample app")
ev("SettingsStore.set('notifications.presentation', 'auto')")

# ---- Menus & OSD ------------------------------------------------------------
ev("SettingsStore.set('layout.osd.style', 'bar-inline')")
select("menus")
check(wait_until(lambda: ev('w.findItem("controlsModule", w.stage("osdStage")) !== null')),
      "in the bar: the real controls button")
check(ev("OsdService.inlineHosts") == 0, "a bar in a preview registers no inline OSD host")
ev("SettingsStore.set('layout.osd.style', 'pill')")
check(wait_until(lambda: ev('w.findItem("menuOnStage", w.stage("osdStage")) !== null')), "the menu on the stage")

# ---- the dock's indicator -------------------------------------------------------
dock = ev('w.findItem("lineDock")')
check(wait_until(lambda: h.eval(dock, "dock !== null")), "a live dock builds")
src = ev("""(function() {
    var out = [];
    (function walk(it) { if (!it) return; if (it.source !== undefined && String(it.source).indexOf("indicators/") >= 0) out.push(String(it.source));
        for (var i = 0; i < it.children.length; i++) walk(it.children[i]); })(w.findItem("lineDock"));
    return out.join("\\n");
})()""").split("\n")
src = [s for s in src if s]
check(len(src) > 0 and all("LineIndicator" in s for s in src), f"its indicators are the override's style ({src[:1]})")

if failures:
    print(f"settings-live-parts: {len(failures)} failure(s)")
    h.exit(1)
print("settings-live-parts: ok")
h.exit(0)
