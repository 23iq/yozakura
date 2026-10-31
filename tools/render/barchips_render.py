#!/usr/bin/env python3
"""Render the island's bar chips (media, notifications, mic) offscreen
(private Xvfb, never the live desktop).

    tools/render/barchips_render.py [--out DIR] [--languages ink,glass,tiles]
                                    [--edges top,left] [--styles classic,islands]
                                    [--palettes user,green] [--no-popups]

The notch is off (notch.enabled false), so ShellLayout homes the media,
bell and muted mic to their bar modules. Per palette x style x edge x
language: the chips at rest (a playing player with art, a muted mic, three
notifications) as barchips-<palette>-<style>-<edge>-<language>.png; on the
top edge also the mic notice (-notice), do-not-disturb with no player
(-quiet) and the media / notifications popups (-popup-media, -popup-notif).
"green" is an all-green test palette (features must follow palette roles).
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ.setdefault("YOZAKURA_TEST_TIMEOUT", "1800")
from settings_render import REPO, color_source, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

import bundled_fonts  # noqa: E402
from island_env import IslandEnv  # noqa: E402
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtCore import QRect  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import DEFAULT_PALETTE  # noqa: E402

W, H = 1600, 900

GREEN = {
    **DEFAULT_PALETTE,
    "background": "#0c130d", "surface": "#111a12", "surfaceDim": "#111a12", "surfaceBright": "#364037",
    "surfaceContainerLowest": "#0b110c", "surfaceContainerLow": "#182219", "surfaceContainer": "#1c271d",
    "surfaceContainerHigh": "#263127", "surfaceContainerHighest": "#313c32", "surfaceVariant": "#3f4a40",
    "primary": "#8fd89a", "overPrimary": "#003914", "primaryContainer": "#145225", "overPrimaryContainer": "#aaf5b4",
    "secondary": "#b6ccb5", "overSecondary": "#223524", "secondaryContainer": "#384b39",
    "overSecondaryContainer": "#d2e8d0", "tertiary": "#a2ceda", "overTertiary": "#02363f",
    "tertiaryContainer": "#214d56", "overTertiaryContainer": "#bfeaf7", "overBackground": "#dde5da",
    "overSurface": "#dde5da", "overSurfaceVariant": "#bfc9bc", "outline": "#899387", "outlineVariant": "#3f4a40",
    "error": "#ffb4ab", "overError": "#690005",
}

SERVICES = {
    "MicrophoneStatus": """pragma Singleton
QtObject {
    property bool available: true; property bool muted: true
    property bool noticeVisible: false; property string noticeScreen: "DP-1"
    function toggleMute() { muted = !muted }
}""",
    "Notifications": """pragma Singleton
QtObject {
    property var notchPopupList: []
    property var popupList: []
    property var list: [{ id: 1 }, { id: 2 }, { id: 3 }]
    property bool silent: false
    property var appNameList: ["Telegram", "Firefox"]
    property var groupsByAppName: ({
        "Telegram": { appName: "Telegram", notifications: [
            { id: 1, appName: "Telegram", appIcon: "telegram", summary: "Mira Tanaka", body: "Sent the deck, take a look", image: "" },
            { id: 2, appName: "Telegram", appIcon: "telegram", summary: "Ken", body: "See you at 22:30", image: "" }] },
        "Firefox": { appName: "Firefox", notifications: [
            { id: 3, appName: "Firefox", appIcon: "firefox", summary: "Download complete", body: "report-q3.pdf", image: "" }] }
    })
    function toggleDnd() { silent = !silent }
    function showsOnScreen(name) { return true }
    function activateNotification(id) {} function attemptInvokeAction(id, a) {}
    function discardNotification(id) {} function discardNotifications(ids) {} function discardAllNotifications() {}
    function notifyInternal() {} function timeoutNotification(id) {} function pauseTimeout(id) {}
    function resumeTimeout(id) {} function pauseAllTimers() {} function resumeAllTimers() {}
}""",
}


def bar(edge: str, style: str) -> dict:
    return {"frameEnabled": False, "containBar": False, "pinnedOnStartup": True, "panels": [{
        "id": "main", "edge": edge, "style": style,
        "groups": {"start": ["launcher", "workspaces"], "end": ["media", "mic", "notifications", "clock"]}}]}


def _walk(item, name: str):
    if item.objectName() == name:
        return item
    for child in item.childItems():
        hit = _walk(child, name)
        if hit is not None:
            return hit
    return None


def find(root, name: str):
    """The item named `name` under `root` (popup stubs are items there)."""
    hit = _walk(root, name)
    if hit is None:
        raise LookupError(name)
    return hit


def shot(win, edge: str, path: Path, popup: bool) -> None:
    image = win.grabWindow()
    if edge == "top":
        rect = QRect(W - 900, 0, 900, 560 if popup else 70)
    else:
        rect = QRect(0, 0, 560 if popup else 70, H)
    image.copy(rect).save(str(path))
    print(path, flush=True)


def render(name: str, pal: dict, art: str, style: str, edge: str, lang: str, out: Path, popups: bool) -> None:
    env = IslandEnv(f"barchips-{name}-{style}-{edge}-{lang}", art=art, bar=bar(edge, style),
                    theme={"language": lang}, notch={"enabled": False, "position": "top"}, palette=pal)
    env.h.module("qs.modules.services", SERVICES)
    win = PanelsEnv.scene(env, W, H, wallpaper="", windows=False)
    h = env.h
    svc = h.load("import QtQuick\nimport qs.modules.services\nQtObject {}")
    QTest.qWait(900)
    base = f"barchips-{name}-{style}-{edge}-{lang}"
    shot(win, edge, out / f"{base}.png", False)
    if edge != "top":
        win.close()
        return
    h.eval(svc, "MicrophoneStatus.muted = false; MicrophoneStatus.noticeVisible = true")
    QTest.qWait(400)
    shot(win, edge, out / f"{base}-notice.png", False)
    h.eval(svc, "MicrophoneStatus.muted = true; MicrophoneStatus.noticeVisible = false")
    # The harness's stub popups are drawn inside the bar window, where an
    # islands panel clips them: popups render from the classic bar only
    popups = popups and style == "classic"
    if popups:
        for obj, suffix in (("mediaPopup", "media"), ("notificationsPopup", "notif")):
            p = find(win.contentItem(), obj)
            h.eval(p, "open()")
            QTest.qWait(900)
            shot(win, edge, out / f"{base}-popup-{suffix}.png", True)
            h.eval(p, "close()")
            QTest.qWait(300)
    h.eval(svc, "MprisController.activePlayer = null; Notifications.silent = true; Notifications.list = []")
    QTest.qWait(500)
    shot(win, edge, out / f"{base}-quiet.png", False)
    if popups:
        p = find(win.contentItem(), "mediaPopup")
        h.eval(p, "open()")
        QTest.qWait(700)
        shot(win, edge, out / f"{base}-popup-empty.png", True)
    win.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "barchips"))
    ap.add_argument("--languages", default="ink,glass,tiles")
    ap.add_argument("--edges", default="top,left")
    ap.add_argument("--styles", default="classic,islands")
    ap.add_argument("--palettes", default="user,green")
    ap.add_argument("--no-popups", action="store_true")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    bundled_fonts.register(REPO)
    state = wallpaper_state()
    cover = state.get("thumbs", {}).get(state.get("current", ""), color_source(state))
    art = ("file://" + cover) if cover else ""
    pals = {"user": palette("dark", state), "green": GREEN}
    for name in args.palettes.split(","):
        for style in args.styles.split(","):
            for edge in args.edges.split(","):
                for lang in args.languages.split(","):
                    render(name, pals[name], art, style, edge, lang, out, not args.no_popups)
    # Skip the interpreter's Qt teardown (it may crash after many scenes)
    sys.stdout.flush()
    os._exit(0)


if __name__ == "__main__":
    sys.exit(main())
