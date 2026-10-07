#!/usr/bin/env python3
"""Render the corner notification toasts offscreen (private Xvfb, never the live desktop).

    tools/render/toasts_render.py [--out DIR] [--mode dark|light]
                                  [--languages ink,glass,tiles] [VARIANT ...]

Draws modules/notifications/CornerToast.qml with fixture notifications, once
per visual language, over your wallpaper with your real config and palette
(see settings_render.py). Variants: single (one toast with an image),
actions (actions + a progress hint + a critical one), stack (a grouped app,
for top and bottom corners), plain (the Settings test toast, whose themed
icon is missing, and a long one that elides). Named icons resolve through a
Quickshell.iconPath stub over /usr/share/icons/hicolor (missing -> "").
Writes <out>/toasts-<variant>-<language>.png.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from kit_env import LANGUAGES, KitEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

MIN = 60000


def notif(i: int, app: str, summary: str, body: str, ago: int, **extra) -> dict:
    return {"id": i, "appName": app, "summary": summary, "body": body, "ago": ago, "urgency": 1,
            "actions": [], "image": "", "appIcon": "", **extra}


# variant -> list of (groups, stackUp); each group is a list of notifications
VARIANTS = {
    "single": [([notif(1, "Telegram", "Mira Tanaka", "Sent the deck, take a look before the review tomorrow "
                       "morning and leave comments inline.", 2, image="ART")], False)],
    "actions": [
        ([notif(2, "Firefox", "Download complete", "report-q3.pdf · 2.4 MB", 0, appIcon="firefox",
                actions=[{"identifier": "open", "text": "Open"}, {"identifier": "show", "text": "Show in folder"}])], False),
        ([notif(3, "Nautilus", "Copying photos", "128 of 366 files to Backup", 0, appIcon="org.gnome.Nautilus",
                hints={"value": 35}, actions=[{"identifier": "cancel", "text": "Cancel"}])], False),
        ([notif(4, "Battery", "Battery low", "8% left. Plug in the charger soon.", 1, urgency=2)], False),
    ],
    "plain": [
        ([notif(10, "Yozakura", "This is a notification", "Sent from Settings › Notifications.", 0,
                appIcon="preferences-system-notifications")], False),
        ([notif(11, "Calendar", "Quarterly planning review with the design, platform and research teams",
                "Agenda: roadmap for the next two quarters, hiring, the theme overhaul and the new "
                "notification centre. Bring the numbers from the last retro and your top three risks "
                "so we can settle owners before Friday.", 4)], True),
        ([notif(12, "Thunderbird", "Mail", "", 12, urgency=2,
                actions=[{"identifier": "open", "text": "Open"}])], False),
    ],
    "stack": [
        ([notif(5, "Mail", "Kōyō", "Warm autumn palette is ready", 1),
          notif(6, "Mail", "Lazy", "Re: weekend plans", 5),
          notif(7, "Mail", "Calendar", "Design review moved", 9)], False),
        ([notif(8, "Slack", "#design", "Three new messages in the thread", 0),
          notif(9, "Slack", "#general", "Standup in 5 minutes", 3)], True),
    ],
}

ICON_DIR = Path("/usr/share/icons/hicolor/scalable/apps")
QUICKSHELL_STUB = """pragma Singleton
import QtQuick
QtObject {
    function iconPath(name, check) {
        return ["firefox"].indexOf(name) >= 0 ? "%s/" + name + ".svg" : ""
    }
}""" % ICON_DIR

SERVICES_STUB = """pragma Singleton
import QtQuick
QtObject {
    property var invoked: []
    function pauseGroupTimers(a) {}
    function resumeGroupTimers(a) {}
    function discardNotifications(ids) {}
    function activateNotification(id) {}
    function attemptInvokeAction(id, ident, d) { invoked = invoked.concat([ident]) }
}"""


def toast(groups: list, stack_up: bool, art: str) -> str:
    items = []
    for n in groups:
        n = dict(n)
        n["time"] = f"__NOW__ - {n.pop('ago')} * {MIN}"
        if n.get("image") == "ART":
            n["image"] = art
        if "hints" in n:
            n["notification"] = {"hints": n.pop("hints")}
        items.append(n)
    js = json.dumps(items).replace('"__NOW__', "Date.now()").replace(f'* {MIN}"', f"* {MIN}")
    return (f"CornerToast {{ width: 360; stackUp: {'true' if stack_up else 'false'}; "
            f"group: ({{ appName: {json.dumps(groups[0]['appName'])}, notifications: {js} }}) }}")


def sheet(variant: str, wall: str, art: str) -> str:
    cells = "\n".join(toast(g, up, art) for g, up in VARIANTS[variant])
    return f"""
import QtQuick
import QtQuick.Window
import qs.modules.components.kit
import qs.modules.notifications
Window {{
    width: 360 + 2 * Space.xxl
    height: col.implicitHeight + 2 * Space.xxl
    visible: true
    color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps(wall)}; fillMode: Image.PreserveAspectCrop }}
    Column {{
        id: col
        x: Space.xxl; y: Space.xxl
        spacing: Space.l
        {cells}
    }}
}}"""


def env_for(lang: str, mode: str, state: dict) -> KitEnv:
    env = KitEnv(f"toasts-render-{lang}", palette=palette(mode, state), user_config=True,
                 overrides={"theme": {"language": lang, "lightMode": mode == "light"}}, wallpaper=state)
    qs = env.root / "qs"
    dst = qs / "modules/notifications"
    shutil.copytree(REPO / "modules/notifications", dst, dirs_exist_ok=True)
    act = qs / "modules/services/activities"
    act.mkdir(parents=True, exist_ok=True)
    shutil.copy(REPO / "modules/services/activities/NotificationProgress.js", act)
    env.h.module("qs.modules.services", {"Notifications": SERVICES_STUB})
    env.h.module("Quickshell", {"Quickshell": QUICKSHELL_STUB})
    env._qmldir(dst, "qs.modules.notifications", only=["CornerToast", "ToastCard"])
    return env


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("variants", nargs="*", default=list(VARIANTS))
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--languages", default=",".join(LANGUAGES))
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    for lang in args.languages.split(","):
        env = env_for(lang, args.mode, state)
        for variant in args.variants:
            win = env.load(sheet(variant, url, url))
            QTest.qWait(900)
            path = out / f"toasts-{variant}-{lang}.png"
            win.grabWindow().save(str(path))
            win.close()
            print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
