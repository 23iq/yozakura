#!/usr/bin/env python3
"""Render the "strips" notification presentation offscreen (private Xvfb, never the live desktop).

    tools/render/strips_render.py [--out DIR] [--palette default|green ...]
                                  [--language ink|glass|tiles|classic ...]
                                  [--scene NAME ...] [--no-sway]

Draws modules/notifications/strips/StripsView.qml (real strips, kit and
theme over the example wallpaper, a bar stand-in on its edge) with fixture
notifications. Scenes: n1 / n3 / n7 (top bar; 7 shows the +N knot), open
(the newest strip opened into its card), bar-bottom, bar-left, edge-left,
edge-bottom, edge-right (strips.edge), plain / washi (materials; the rest
use paper). Writes <out>/strips-<palette>-<language>-<scene>.png, a contact
sheet per palette <out>/strips-<palette>.png (rows = languages) and the sway
of a new strip, <out>/strips-sway-<palette>.png (frames left to right).
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lighting_render as lit  # noqa: E402  (enters the private Xvfb)

from kit_env import KitEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

REPO = lit.REPO
W, H = 980, 520
BAR = 34
MIN = 60000


def notif(i, app, summary, body, ago, **extra):
    return {"id": i, "appName": app, "summary": summary, "body": body, "ago": ago, "urgency": 1,
            "actions": [], "image": "", "appIcon": "", **extra}


# Newest first
FIXTURES = [
    notif(1, "Firefox", "Download complete", "report-q3.pdf · 2.4 MB", 0, appIcon="firefox",
          actions=[{"identifier": "open", "text": "Open"}, {"identifier": "show", "text": "Show in folder"}]),
    notif(2, "Mail", "Mira Tanaka", "Sent the deck, take a look before the review tomorrow morning.", 1),
    notif(3, "Calendar", "Design review in 10 min", "Room 4 · with Kenji and Aiko", 3),
    notif(4, "Battery", "Battery low", "8% left. Plug in the charger soon.", 4, urgency=2),
    notif(5, "Slack", "#design", "Three new messages in the thread", 6),
    notif(6, "Music", "Hikari", "Utada Hikaru · First Love", 8, urgency=0),
    notif(7, "Telegram", "Lazy", "Weekend plans?", 12),
]

SCENES = {
    "n1": {"n": 1},
    "n3": {"n": 3},
    "n7": {"n": 7},
    "open": {"n": 3, "open": 0},
    "bar-bottom": {"n": 3, "bar": "bottom"},
    "bar-left": {"n": 3, "bar": "left"},
    "edge-left": {"n": 3, "edge": "left"},
    "edge-bottom": {"n": 3, "edge": "bottom"},
    "edge-right": {"n": 4, "edge": "right"},
    "plain": {"n": 3, "material": "plain"},
    "washi": {"n": 3, "material": "washi"},
}

NOTIFICATIONS_STUB = """pragma Singleton
import QtQuick
QtObject {
    property string presentation: "strips"
    property var popupAppNameList: []
    property var popupGroupsByAppName: ({})
    function showsOnScreen(n) { return true }
    function pauseGroupTimers(a) {}
    function resumeGroupTimers(a) {}
    function activateNotification(id) {}
    function attemptInvokeAction(id, ident, d) {}
    function discardNotifications(ids) {}
    function setGroups(list) {
        var g = {};
        for (var i = 0; i < list.length; i++) {
            var n = list[i];
            n.time = Date.now() - n.ago * %d;
            g[n.appName] = { appName: n.appName, time: n.time, notifications: [n] };
        }
        popupGroupsByAppName = g;
        popupAppNameList = list.map(function (n) { return n.appName });
    }
}""" % MIN

ICON_DIR = Path("/usr/share/icons/hicolor/scalable/apps")
QUICKSHELL_STUB = """pragma Singleton
import QtQuick
QtObject {
    function iconPath(name, check) {
        return ["firefox"].indexOf(name) >= 0 ? "%s/" + name + ".svg" : ""
    }
}""" % ICON_DIR

SCENE = """
import QtQuick
import QtQuick.Window
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.modules.notifications.strips
Window {
    width: %(w)d; height: %(h)d; visible: true; color: "black"
    function show(list) { Notifications.setGroups(list) }
    Image { anchors.fill: parent; source: "%(wall)s"; fillMode: Image.PreserveAspectCrop; sourceSize.width: %(w)d }
    StyledRect {
        visible: "%(bar)s" !== ""
        variant: "bg"
        glassSurface: "bar"
        x: "%(bar)s" === "right" ? parent.width - width : 0
        y: "%(bar)s" === "bottom" ? parent.height - height : 0
        width: "%(bar)s" === "left" || "%(bar)s" === "right" ? %(bt)d : parent.width
        height: "%(bar)s" === "left" || "%(bar)s" === "right" ? parent.height : %(bt)d
        radius: 0
        KitText { anchors.centerIn: parent; role: "label"; text: "Sat 31  18:20"; rotation: parent.width < parent.height ? 270 : 0 }
    }
    StripsView {
        anchors.fill: parent
        screenName: "R"
        panel: ({ panelZones: ({ "%(bar)s": %(bt)d }), dockEnabled: false })
    }
}"""


def env_for(pal: str, lang: str, material: str, edge: str, anim: int) -> KitEnv:
    env = KitEnv(f"strips-{pal}-{lang}-{material}-{edge}-{anim}", palette=lit.palette(pal),
                 overrides={"theme": {"language": lang, "animDuration": anim},
                            "notifications": {"presentation": "strips",
                                              "strips": {"material": material, "edge": edge}}})
    qs = env.root / "qs"
    dst = qs / "modules/notifications"
    shutil.copytree(REPO / "modules/notifications", dst, dirs_exist_ok=True)
    act = qs / "modules/services/activities"
    act.mkdir(parents=True, exist_ok=True)
    shutil.copy(REPO / "modules/services/activities/NotificationProgress.js", act)
    env.h.module("qs.modules.services", {"Notifications": NOTIFICATIONS_STUB})
    env.h.module("Quickshell", {"Quickshell": QUICKSHELL_STUB})
    env._qmldir(dst, "qs.modules.notifications", only=["ToastCard", "ToastGroup"])
    env._qmldir(dst / "strips", "qs.modules.notifications.strips")
    return env


def scene(env: KitEnv, bar: str):
    return env.load(SCENE % {"w": W, "h": H, "wall": lit.wallpaper("09"), "bar": bar, "bt": BAR})


def show(env, win, n: int) -> None:
    env.h.eval(win, f"show({json.dumps(FIXTURES[:n])})")


def render(out: Path, pal: str, lang: str, names: list[str]) -> list[Path]:
    paths, envs = [], {}
    for name in names:
        s = SCENES[name]
        key = (s.get("material", "paper"), s.get("edge", "auto"))
        if key not in envs:
            envs[key] = env_for(pal, lang, key[0], key[1], 0)
        env = envs[key]
        win = scene(env, s.get("bar", "top"))
        show(env, win, s["n"])
        QTest.qWait(250)
        if "open" in s:
            lst = env.h.find(win, "stripsList")
            env.h.eval(lst, f"itemAtIndex({s['open']}).expanded = true")
            QTest.qWait(250)
        path = out / f"strips-{pal}-{lang}-{name}.png"
        win.grabWindow().save(str(path))
        win.close()
        paths.append(path)
        print(path)
    return paths


def sway(out: Path, pal: str, lang: str) -> None:
    from PIL import Image
    env = env_for(pal, lang, "paper", "auto", 300)
    win = scene(env, "top")
    env.h.eval(win, f"show({json.dumps(FIXTURES[1:4])})")
    QTest.qWait(2600)
    env.h.eval(win, f"show({json.dumps(FIXTURES[:4])})")
    frames = []
    crop = (W - 420, 0, W, 300)
    for step in range(7):
        QTest.qWait(110 if step else 40)
        frames.append(win.grabWindow().copy(*crop[:2], crop[2] - crop[0], crop[3] - crop[1]))
    win.close()
    fw, fh = crop[2] - crop[0], crop[3] - crop[1]
    sheet = Image.new("RGB", (fw * len(frames), fh))
    for i, f in enumerate(frames):
        p = out / f".sway-{i}.png"
        f.save(str(p))
        sheet.paste(Image.open(p).convert("RGB"), (i * fw, 0))
        p.unlink()
    path = out / f"strips-sway-{pal}.png"
    sheet.save(path)
    print(path)


def contact(out: Path, pal: str, grid: list[list[Path]]) -> None:
    from PIL import Image
    tw, th = W // 2, H // 2
    cols = max(len(r) for r in grid)
    img = Image.new("RGB", (cols * tw, len(grid) * th))
    for y, row in enumerate(grid):
        for x, p in enumerate(row):
            img.paste(Image.open(p).convert("RGB").resize((tw, th)), (x * tw, y * th))
    path = out / f"strips-{pal}.png"
    img.save(path)
    print(path)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--palette", action="append", choices=["default", "green"])
    ap.add_argument("--language", action="append", choices=["ink", "glass", "tiles", "classic"])
    ap.add_argument("--scene", action="append", choices=list(SCENES))
    ap.add_argument("--no-sway", action="store_true")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for pal in args.palette or ["default", "green"]:
        grid = [render(out, pal, lang, args.scene or list(SCENES)) for lang in args.language or ["ink", "glass", "tiles"]]
        contact(out, pal, grid)
        if not args.no_sway:
            sway(out, pal, (args.language or ["ink"])[0])
    return 0


if __name__ == "__main__":
    sys.exit(main())
