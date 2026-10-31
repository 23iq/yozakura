#!/usr/bin/env python3
"""Render the card host (modules/shell/hosts/CardHost.qml) offscreen
(private Xvfb, never the live desktop).

    tools/render/cardhost_render.py [--out DIR] [--languages ink,glass,tiles]
                                    [--edges top,left] [--views timerHub,voice,aiquick]
                                    [--palettes user,green]

The notch is off (notch.enabled false), the bar on each edge, the whole
desktop of tests/lib/panels_env.py around it. The real CardHost opens the
real notch panel (timers hub, voice input) or the real AI quick ask
(QuickAskCard, empty, with its AI pieces stubbed) beside the bar, as
cardhost-<palette>-<edge>-<view>-<language>.png (the corner around the card
and the bar). "green" is an all-green test palette (features follow palette
roles).
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ.setdefault("YOZAKURA_TEST_TIMEOUT", "1800")
from settings_render import REPO, color_source, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

import bundled_fonts  # noqa: E402
import panels_stubs  # noqa: E402
from barchips_render import GREEN  # noqa: E402
from island_env import TIMERS, IslandEnv  # noqa: E402
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtCore import QRect  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

W, H = 1600, 900
VIEWS = ["timerHub", "voice", "aiquick"]

# QuickAskCard's AI pieces (aicenter.common, with its Chip and Spinner, is real):
# the empty card shows only its input row
AI_STUBS = {
    "qs.modules.aicenter.markdown": {
        "MarkdownView": "Item { property string text; property color textColor; property bool streaming }",
        "CopyButton": "Item { property string copyText }"},
    "qs.modules.aicenter.chat": {
        "PermissionCard": "Item { property string title; property string tool; property string category;"
                          " property string detail; signal decided(string d) }",
        "AttachmentStrip": "Item { property var attachments; property bool removable; signal removeRequested(int index) }"},
    "qs.modules.aicenter.transcript": {"ThinkingBlock": "Item { property string text; property bool streaming }"},
}
AI = """pragma Singleton
QtObject {
    property QtObject quick: QtObject { property ListModel rows: ListModel {} property bool busy: false }
    property var quickModel: ({ icon: "", name: "Claude Sonnet" })
    signal modelSelectionRequested()
    function _ensureInit() {} function askQuick(t, a) {} function continueInSidebar() {}
}"""
GLOBALS_EXTRA = """    property string quickAskKind: "chat"
    property var quickAskAttachments: []
    function hideQuickAsk() {} function toggleAssistant() {}
"""


def bar(edge: str) -> dict:
    return {"frameEnabled": False, "containBar": False, "pinnedOnStartup": True, "panels": [{
        "id": "main", "edge": edge, "style": "classic",
        "groups": {"start": ["launcher", "workspaces"], "center": [], "end": ["clock"]}}]}


def mirror_hosts(env: IslandEnv) -> None:
    """The real hosts; SurfaceHost's PanelWindow becomes a full-window Item."""
    qs = env.root / "qs"
    hosts = qs / "modules/shell/hosts"
    hosts.mkdir(parents=True, exist_ok=True)
    src = (REPO / "modules/shell/hosts/SurfaceHost.qml").read_text()
    item = src.replace("import Quickshell.Wayland\n", "").replace("PanelWindow {", "Item {\n    property var screen\n    property var mask", 1)
    item = re.sub(r"\n    anchors \{[^}]*\}", "", item, count=1)
    item = "\n".join(ln for ln in item.split("\n")
                     if not re.match(r'\s*(color: "transparent"|exclusionMode:|WlrLayershell\.)', ln))
    (hosts / "SurfaceHost.qml").write_text(item)
    for f in ("HostBackdrop", "CardHost"):
        shutil.copy(REPO / f"modules/shell/hosts/{f}.qml", hosts / f"{f}.qml")
    env._qmldir(hosts, "qs.modules.shell.hosts")
    quick = qs / "modules/aicenter/quickask"
    quick.mkdir(parents=True, exist_ok=True)
    shutil.copy(REPO / "modules/aicenter/quickask/QuickAskCard.qml", quick / "QuickAskCard.qml")
    env._qmldir(quick, "qs.modules.aicenter.quickask")
    common = qs / "modules/aicenter/common"
    shutil.copytree(REPO / "modules/aicenter/common", common, dirs_exist_ok=True)
    env._qmldir(common, "qs.modules.aicenter.common")
    for module, types in AI_STUBS.items():
        env.h.module(module, types)
    env.h.module("qs.modules.services", {"Ai": AI})
    env.h.module("qs.modules.globals", {"GlobalStates": panels_stubs.GLOBAL_STATES.replace(
        "    function clearLauncherState() {}", GLOBALS_EXTRA + "    function clearLauncherState() {}")})


SCENE = """import QtQuick
import qs.modules.components.kit
import qs.modules.shell.hosts
import qs.modules.widgets.defaultview.panels
import qs.modules.aicenter.quickask
import "NotchPanelsRef.js" as Ref
Item {
    id: scene
    property var screen
    property string which: "timerHub"
    anchors.fill: parent
    z: 100
    CardHost {
        id: card
        objectName: "card"
        anchors.fill: parent
        screen: scene.screen
        padding: scene.which === "aiquick" ? Space.m : 0
        preferredWidth: scene.which === "aiquick" ? 0 : Ref.widthFor(scene.which, 440)
    }
    TimerHubPanel { id: hub; visible: false; screenName: "DP-1"; maxRows: 5 }
    VoicePanel { id: voice; visible: false; screenName: "DP-1" }
    QuickAskCard { id: quick; visible: false }
    function show() {
        card.open(scene.which === "voice" ? voice : scene.which === "aiquick" ? quick : hub, scene.screen);
    }
}"""


def render(name: str, pal: dict, art: str, wall: str, edge: str, view: str, lang: str, out: Path) -> None:
    env = IslandEnv(f"cardhost-{name}-{edge}-{view}-{lang}", art=art, bar=bar(edge),
                    theme={"language": lang}, notch={"enabled": False, "position": "top"}, palette=pal)
    mirror_hosts(env)
    app = env.root / "app"
    app.mkdir(exist_ok=True)
    (app / "NotchPanelsRef.js").write_text(
        (REPO / "modules/widgets/defaultview/panels/NotchPanels.js").read_text())
    win = PanelsEnv.scene(env, W, H, wallpaper=wall, windows=True)
    h = env.h
    h.eval(win, f"TimersService.timers = {TIMERS}; TimersService.hubOpen = true; TimersService.hubMode = 'timer'; "
                "VoiceService.panelOpen = true")
    scene = env.load(SCENE)
    scene.setParentItem(win.contentItem())
    h.eval(scene, f'which = "{view}"')
    scene.setProperty("screen", h.eval(win, "host.screen"))
    QTest.qWait(600)
    h.eval(scene, "show()")
    QTest.qWait(900)
    card = h.find(scene, "card")
    ax, ay, aw, ah = (int(h.eval(card, f"area.{k}")) for k in ("x", "y", "w", "h"))
    pad = 60
    if edge == "left":
        rect = QRect(0, 0, min(W, ax + aw + pad * 3), min(H, ay + ah + pad * 2))
    else:
        x0 = max(0, ax - pad * 3)
        rect = QRect(x0, 0, W - x0, min(H, ay + ah + pad * 2))
    path = out / f"cardhost-{name}-{edge}-{view}-{lang}.png"
    win.grabWindow().copy(rect).save(str(path))
    print(path, flush=True)
    win.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "cardhost"))
    ap.add_argument("--languages", default="ink,glass,tiles")
    ap.add_argument("--edges", default="top,left")
    ap.add_argument("--views", default=",".join(VIEWS))
    ap.add_argument("--palettes", default="user,green")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    bundled_fonts.register(REPO)
    state = wallpaper_state()
    cover = state.get("thumbs", {}).get(state.get("current", ""), color_source(state))
    art = ("file://" + cover) if cover else ""
    wall = color_source(state) or ""
    pals = {"user": palette("dark", state), "green": GREEN}
    for name in args.palettes.split(","):
        for edge in args.edges.split(","):
            for view in args.views.split(","):
                for lang in args.languages.split(","):
                    render(name, pals[name], art, wall, edge, view, lang, out)
    # Skip the interpreter's Qt teardown (it may crash after many scenes)
    sys.stdout.flush()
    os._exit(0)


if __name__ == "__main__":
    sys.exit(main())
