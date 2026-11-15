"""Live previews stay readable on a big screen (modules/settings/AGENTS.md,
LIVE PREVIEWS: readable zoom, cut, overview screen), offscreen.

On a 2560x1440 and a 3840x2160 screen (YOZAKURA_TEST_SCREEN, the owner's is
2560 wide; the real parts are laid out at that size):
* every picture card or stage part that asks to be readable
  (`readableGlyph`) draws its smallest text at 10 px or more in the window
  (at its `maxZoom` cap it may stay under: then at least 8 px; a hosted
  window's picture card, the launcher's, at least 6 px: its corner);
* the Screen canvas lays the parts out on the overview screen (at most
  1280 px wide), whatever the monitor: a bar's module there is at least
  ~15 px tall.
The pages: Bar (shape cards, workspace / clock cards), Dock (style cards),
Island (shape cards), Menus & OSD (style cards), Launcher.
"""
import os
import subprocess
import sys
from pathlib import Path

SCREENS = ["2560x1440", "3840x2160"]

if os.environ.get("YOZAKURA_TEST_SCREEN") is None:
    # one process per screen (the screen is fixed when the harness starts)
    code = 0
    for s in SCREENS:
        r = subprocess.run([sys.executable, __file__], env={**os.environ, "YOZAKURA_TEST_SCREEN": s})
        code = code or r.returncode
    sys.exit(code)

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

import live_previews  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from settings_env import SettingsEnv  # noqa: E402
from waits import wait_until  # noqa: E402

screen = os.environ["YOZAKURA_TEST_SCREEN"]
env = SettingsEnv("settings-live-legible", overrides={"dock": {"enabled": True}})
h = env.h
failures: list[str] = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + f"[{screen}] " + what)
    if not ok:
        failures.append(what)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings
Window {
    id: w
    width: 1180; height: 2400; visible: true
    // every readable live part shown: [{name, glyph (window px), capped}]
    function parts() {
        const out = [];
        const glyphOf = part => {
            let least = 0;
            const walk = it => {
                if (!it || it.visible === false || it.opacity === 0)
                    return;
                if (it.font !== undefined && typeof it.text === "string" && it.text !== "" && it.height > 0) {
                    const px = it.font.pixelSize > 0 ? it.font.pixelSize : it.font.pointSize * 1.33;
                    const r = it.mapToItem(null, 0, 0, it.width, it.height);
                    const g = px * r.height / it.height;
                    if (g > 0 && (least === 0 || g < least))
                        least = g;
                }
                for (let i = 0; i < (it.children || []).length; i++)
                    walk(it.children[i]);
            };
            walk(part.item);
            return least;
        };
        const find = it => {
            if (!it || it.visible === false)
                return;
            const hosted = it.objectName === "liveHosted";
            if (it.readableGlyph !== undefined && it.shownScale !== undefined && (it.readableGlyph > 0 || hosted) && it.settled) {
                const r = it.mapToItem(null, 0, 0, it.width, it.height);
                if (r.y + r.height > 0 && r.y < w.height)
                    out.push({ "name": String(it.source).split("/").pop() + "@" + Math.round(r.x) + "," + Math.round(r.y),
                               "glyph": glyphOf(it), "capped": it.shownScale >= it.maxZoom - 0.001, "hosted": hosted });
            }
            for (let i = 0; i < (it.children || []).length; i++)
                find(it.children[i]);
        };
        find(w.contentItem);
        return JSON.stringify(out);
    }
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (!item) return null;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")

import json  # noqa: E402

for cat in ("bar", "dock", "notch", "menus", "launcher"):
    h.eval(shell, f'select("{cat}")')
    env.wait_page(win)
    live_previews.wait_built(env, settle_ms=1200)
    parts = json.loads(h.eval(win, "parts()"))
    check(len(parts) > 0, f"{cat}: readable live parts shown ({len(parts)})")
    for p in parts:
        if p["glyph"] <= 0:
            continue
        # a hosted surface (the launcher) in a picture card: its corner at
        # its `minZoom` (a layout picture of a whole window)
        want = 6 if p["hosted"] else (8 if p["capped"] else 9.5)
        check(p["glyph"] >= want, f"{cat}: {p['name']} smallest text {p['glyph']:.1f} px (want {want})")
    if cat == "bar":
        mini = h.eval(win, 'findItem("screenCanvasMini")')
        k = h.eval(mini, "k") if mini is not None else 0
        check(mini is not None and wait_until(lambda m=mini: h.eval(m, "moduleRects.length") > 0),
              "the canvas measured the real modules")
        tallest = max((m["h"] for m in json.loads(h.eval(mini, "JSON.stringify(moduleRects)"))), default=0)
        check(tallest >= 13, f"canvas: a module is {tallest:.1f} px (scale {k:.3f}, want 13)")
        check(h.eval(mini, "width / k") <= 1280.5, "the canvas lays the parts out on the overview screen")

if failures:
    print(f"{len(failures)} failure(s)")
    h.exit(1)
print("ok")
h.exit(0)
