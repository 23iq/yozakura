#!/usr/bin/env python3
"""RemoteWallpapers: the wallpaper manager of a separate window process.

The real component (modules/widgets/dashboard/wallpapers/RemoteWallpapers.qml)
over stubs: it follows what the main shell saves in wallpapers.json (current
and per-screen wallpapers, bundled ids resolved, scheme, color preset,
folder), lists the library like the main shell's scanner (depth maps apart,
the bundled wallpapers when the folders hold none), gives the same
thumbnail / color / lock-frame sources, and asks the main shell for every
change (windows.relay "wallpaper.call") without writing anything itself.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from qmlharness import HARNESS_HOME, Harness, hard_exit  # noqa: E402

from waits import settle  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


h = Harness("remote-wallpapers")
h.module("Quickshell", {"Quickshell": "pragma Singleton\nQtObject { function env(n) { return n === \"HOME\" ? \"/home/u\" : \"\" } }"})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command: []; property bool running: false; property var stdout; "
               "property int starts: 0; onRunningChanged: if (running) starts++ }",
    "StdioCollector": "QtObject { property string text; signal streamFinished() }",
    "FileView": "QtObject { property string path; property bool watchChanges; property bool printErrors; "
                "property int writes: 0; signal loaded(); signal loadFailed(int e); signal fileChanged(); "
                "function text() { return \"\" } function reload() {} function setText(t) { writes++ } }",
})
h.module("qs.modules.services", {"BackendService": """pragma Singleton
QtObject {
    property var calls: []
    function call(m, p, cb) { calls = calls.concat([{ "method": m, "params": p }]) }
}"""})
h.singleton("qs.config", "Config", "QtObject { property var desktop: ({ wallpaperFolders: [] }) }")
h.module("qs.modules.globals", {})
h.copy("modules/widgets/dashboard/wallpapers/RemoteWallpapers.qml", "app", siblings=False)
h.stub("WallpaperColorPresets", "QtObject { property var names: [\"nord\", \"rose\"]; function scan() {} function reloadWatchers() {} }")
root = h.load("""
import QtQuick
import qs.modules.services
Item {
    property alias m: m
    RemoteWallpapers { id: m }
}""", auto_stub=False)


def ev(expr):
    return h.eval(root, expr)


bundled = ev("m.fallbackDir")
check(bundled.endswith("assets/wallpapers_example"), f"the bundled folder, got {bundled}")
saved = {"wallPath": "~/Pictures/walls", "currentWall": "/home/u/Pictures/walls/a.png",
         "perScreenWallpapers": {"DP-1": "/home/u/Pictures/walls/b.mp4"},
         "matugenScheme": "scheme-tonal-spot", "activeColorPreset": "", "tintEnabled": True}
ev(f"m.applySaved({json.dumps(json.dumps(saved))})")
settle()
check(ev("m.wallpaperDir") == "/home/u/Pictures/walls", "the folder, ~ expanded")
check(ev("m.currentWallpaper") == "/home/u/Pictures/walls/a.png", "the current wallpaper")
check(json.loads(ev("JSON.stringify(m.perScreenWallpapers)")) == {"DP-1": "/home/u/Pictures/walls/b.mp4"}, "per screen")
check(ev("m.currentMatugenScheme") == "scheme-tonal-spot" and ev("m.tintEnabled") is True, "scheme and tint")
check(ev("m.scan.starts") >= 1, "the library is scanned")
scan = "\n".join(["/home/u/Pictures/walls/a.png", "/home/u/Pictures/walls/b.mp4",
                  "/home/u/Pictures/walls/a.depth.png", bundled + "/sakura.jpg"])
ev(f"m.applyScan({json.dumps(scan)})")
check(json.loads(ev("JSON.stringify(m.wallpaperPaths)")) == ["/home/u/Pictures/walls/a.png", "/home/u/Pictures/walls/b.mp4"],
      "the folder's wallpapers, depth maps and bundled files apart")
check(json.loads(ev("JSON.stringify(m.depthMaps)")) == ["/home/u/Pictures/walls/a.depth.png"], "depth maps")
check(ev("m.currentIndex") == 0 and ev("m.initialLoadCompleted") is True, "index of the current one")
ev(f"m.applyScan({json.dumps(bundled + '/sakura.jpg')})")
check(ev("m.usingFallback") is True and json.loads(ev("JSON.stringify(m.wallpaperPaths)")) == [bundled + "/sakura.jpg"],
      "an empty folder lists the bundled wallpapers")
# a bundled id saved by the main shell resolves to this install's copy
ev(f"m.applySaved({json.dumps(json.dumps({'wallPath': '', 'currentWall': 'bundled:sakura.jpg'}))})")
check(ev("m.wallpaperDir") == bundled, "no folder: the bundled one")
cache = f"{HARNESS_HOME}/.cache/yozakura"
check(ev("m.getFileType('/x/a.MP4')") == "video" and ev("m.getFileType('/x/a.gif')") == "gif", "file types")
check(ev("m.getColorSource('/x/a.png')") == "/x/a.png", "an image is its own color source")
check(ev("m.getLockscreenFramePath('/x/a.mp4')") == cache + "/lockscreen/a.mp4.jpg", "a video's lock frame")
check(ev("m.getDisplaySource('/x/a.txt')") == "/x/a.txt", "an unknown file is shown as is")
check(json.loads(ev("JSON.stringify(m.colorPresets)")) == ["nord", "rose"], "color presets listed")

ev("m.setWallpaper('/w/c.png', 'DP-1')")
ev("m.setMatugenScheme('scheme-content')")
ev("m.clearAllPerScreenWallpapers()")
calls = json.loads(ev("JSON.stringify(BackendService.calls)"))
check([c["method"] for c in calls] == ["windows.relay"] * 3, f"every change goes to the main shell, got {calls}")
check(calls[0]["params"] == {"to": "shell", "topic": "wallpaper.call", "data": {"method": "setWallpaper", "args": ["/w/c.png", "DP-1"]}},
      "setWallpaper with its screen")
check(calls[1]["params"]["data"] == {"method": "setMatugenScheme", "args": ["scheme-content"]}, "the scheme")
check(ev("m.saved.writes") == 0, "wallpapers.json is never written here")

if failures:
    print(f"{len(failures)} failure(s)")
    hard_exit(1)
print("remote-wallpapers: ok")
hard_exit(0)
