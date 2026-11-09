"""VideoWallpaper + VideoProxyService: which file a video wallpaper plays.

The real VideoProxyService runs against a stub BackendService that records
`wallpaper.videoProxy` calls and lets the test answer them or push the
`wallpaper.videoProxy` event. Checks: the original plays while a copy is
made and the copy replaces it once ready, answers are shared per file and
size, a stale answer never replaces a newer source, and `original`, errors,
a silent backend or the option turned off all play the original.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer  # noqa: E402

h = Harness("video-proxy")
# Real (tiny) files: the players open whatever they are given.
media = h.root / "media"  # removed with the harness tree
media.mkdir()
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "color=c=pink:s=64x36:rate=10", "-t", "1",
                "-c:v", "libx264", "-pix_fmt", "yuv420p", str(media / "big.mp4")], check=True, timeout=60)
for name in ["small", "err", "a", "b", "race", "copy-big", "copy-a", "copy-race"]:
    shutil.copy(media / "big.mp4", media / f"{name}.mp4")
M = str(media)


def f(text):
    """Test shorthand -> real files: /v/<name> sources, /c/<name> copies."""
    return text.replace("/v/", M + "/").replace("/c/", M + "/copy-")


h.module("Quickshell", {"Singleton": "QtObject {}"})
h.module("qs.modules.services", {
    "BackendService": """pragma Singleton
import QtQuick
QtObject {
    property var calls: []
    property var subCb: null
    property int subs: 0
    function call(method, params, cb) { calls = calls.concat([{ method: method, params: params, cb: cb }]); }
    function addSubscription(services, cb) { subs++; subCb = cb; return subs; }
    function answer(i, res, err) { calls[i].cb(res, err || null); }
    function event(data) { subCb("wallpaper.videoProxy", data); }
}""",
    "VideoProxyService": (REPO / "modules/services/VideoProxyService.qml").read_text(),
})
h.module("qs.config", {"Config": """pragma Singleton
import QtQuick
QtObject { property QtObject performance: QtObject { property bool videoWallpaperDownscale: true } }"""})
h.module("qs.modules.globals", {"GlobalStates": "pragma Singleton\nimport QtQuick\nQtObject { property int videoSyncTick: 0 }"})
palette = ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer",
           "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary",
           "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow",
           "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]
h.module("qs.modules.theme", {"Colors": "pragma Singleton\nimport QtQuick\nQtObject {\n"
                              + "\n".join(f'    property color {n}: "#808080"' for n in palette) + "\n}"})
h.copy("modules/widgets/dashboard/wallpapers/VideoWallpaper.qml", siblings=False)

root = h.load(f("""import QtQuick
import qs.config
import qs.modules.services
Item {
    width: 320
    height: 180
    property alias first: first
    property alias second: second
    VideoWallpaper { id: first; anchors.fill: parent; sourceFile: "/v/big.mp4" }
    VideoWallpaper { id: second; anchors.fill: parent }
}"""), auto_stub=False)
ok = True


def check(name, cond, detail=""):
    global ok
    ok &= bool(cond)
    print(("PASS " if cond else "FAIL ") + name + (" " + detail if detail else ""))


def ev(expr):
    return h.eval(root, f(expr))


def js(expr):
    return json.loads(ev("JSON.stringify(" + expr + ")"))


def pump(ms):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


def calls():
    return js("BackendService.calls.map(c => ({ method: c.method, params: c.params }))")


pump(50)
# --- the original plays while the copy is made, then the copy ----------------
check("asks for a copy at the item's size",
      calls() == [{"method": "wallpaper.videoProxy", "params": {"path": f("/v/big.mp4"), "width": 320, "height": 180}}],
      str(calls()))
check("nothing plays before the answer", ev("first.playingFile") == "")
ev('BackendService.answer(0, { source: "/v/big.mp4", width: 320, height: 180, state: "pending" })')
check("pending: the original plays", ev("first.playingFile") == f("/v/big.mp4"))
check("subscribed for the finished copy", ev("BackendService.subs") == 1)
ev('BackendService.event({ source: "/v/big.mp4", width: 320, height: 180, state: "ready", path: "/c/big.mp4" })')
check("ready: the copy replaces the original", ev("first.playingFile") == f("/c/big.mp4"))

# --- a second screen of the same size reuses the answer ----------------------
ev('second.sourceFile = "/v/big.mp4"')
check("known copy is played at once without asking again",
      ev("second.playingFile") == f("/c/big.mp4") and len(calls()) == 1, str(calls()))

# --- option off --------------------------------------------------------------
ev("Config.performance.videoWallpaperDownscale = false")
check("option off: the original plays", ev("first.playingFile") == f("/v/big.mp4") and len(calls()) == 1)
ev("Config.performance.videoWallpaperDownscale = true")
check("option back on: the copy again", ev("first.playingFile") == f("/c/big.mp4"))

# --- original / error answers ------------------------------------------------
ev('first.sourceFile = "/v/small.mp4"')
n = len(calls()) - 1
ev(f'BackendService.answer({n}, {{ source: "/v/small.mp4", width: 320, height: 180, state: "original" }})')
check("original: the source plays", ev("first.playingFile") == f("/v/small.mp4"))
ev('first.sourceFile = "/v/err.mp4"')
n = len(calls()) - 1
ev(f'BackendService.answer({n}, null, "socket closed")')
check("backend error: the source plays", ev("first.playingFile") == f("/v/err.mp4"))

# --- a stale answer never replaces a newer source ----------------------------
ev('first.sourceFile = "/v/a.mp4"')
stale = len(calls()) - 1
ev('first.sourceFile = "/v/b.mp4"')
ev(f'BackendService.answer({stale}, {{ source: "/v/a.mp4", width: 320, height: 180, state: "ready", path: "/c/a.mp4" }})')
check("stale answer ignored", ev("first.playingFile") != f("/c/a.mp4"), ev("first.playingFile"))

# --- a silent backend does not keep the wallpaper empty ----------------------
check("still waiting for b", ev("first.playingFile") == "")
pump(3300)
check("no answer after 3 s: the original plays", ev("first.playingFile") == f("/v/b.mp4"))

# --- the finished event overtakes the "pending" answer ------------------------
ev('second.sourceFile = "/v/race.mp4"')
n = len(calls()) - 1
ev('BackendService.event({ source: "/v/race.mp4", width: 320, height: 180, state: "ready", path: "/c/race.mp4" })')
ev(f'BackendService.answer({n}, {{ source: "/v/race.mp4", width: 320, height: 180, state: "pending" }})')
check("late pending answer keeps the copy", ev("second.playingFile") == f("/c/race.mp4"), ev("second.playingFile"))
check("late pending answer keeps the state",
      ev('VideoProxyService._known[VideoProxyService._key("/v/race.mp4", 320, 180)].state') == "ready")

h.exit(0 if ok else 1)
