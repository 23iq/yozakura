"""Offscreen environment for the lock screen (modules/lockscreen).

Built on SettingsEnv: the lock screen files, its styles, the shared UI kit,
StyledRect, Styling, Metrics, Motion, Glass, Icons, NotchVisualizer and the
clock fonts are the real repo files; Config (config/defaults + `overrides`),
Colors (a palette dict) and I18n are generated. MprisController,
CavaService, Battery, NetworkService, GlobalStates and the Wayland lock / PAM
types are small stand-ins (fake PAM: only "correct" authenticates).

Used by tests/lockscreen.test.py and tools/render/lockscreen_render.py.
"""
from __future__ import annotations

import json
import shutil

from qmlharness import REPO
from settings_env import SettingsEnv
from PySide6.QtCore import qInstallMessageHandler

MIRROR = [
    "modules/lockscreen",
    "modules/desktop/clockstyles",
    "modules/widgets/defaultview/NotchVisualizer.qml",
    "modules/theme/Icons.qml",
    "modules/theme/GlassContrast.js",
    "modules/components/signatures",
    "modules/components/surfaceeffects",
    "assets/fonts/clock",
    "config/ColorSpec.js",
    "config/JsonUtil.js",
]

SERVICES = {
    "MprisController": """pragma Singleton
QtObject { property var activePlayer: null; property bool canGoPrevious: true; property bool canGoNext: true
 property bool canTogglePlaying: true; property int toggles: 0
 function togglePlaying() { toggles++ } function previous() {} function next() {} }""",
    "CavaService": """pragma Singleton
QtObject { property bool available: true; property int consumerCount: 0; property var keys: ({})
 function setConsumer(k, a) { keys[k] = a; var n = 0; for (var x in keys) if (keys[x]) n++; consumerCount = n; }
 function levels(n) { var o = []; for (var i = 0; i < n; i++) o.push(0.25 + 0.6 * Math.abs(Math.sin(i * 1.7))); return o; } }""",
    "GameModeClient": "pragma Singleton\nQtObject { property bool toggled: false }",
    "PowerProfileClient": "pragma Singleton\nQtObject { property string currentProfile: \"balanced\" }",
    "Battery": """pragma Singleton
import qs.modules.theme
QtObject { property bool available: true; property real percentage: 76; property bool isPluggedIn: false
 function getBatteryIcon() { return Icons.batteryHigh; } }""",
    "NetworkService": """pragma Singleton
import qs.modules.theme
QtObject { property bool ethernet: false; property bool wifiEnabled: true; property string wifiStatus: "connected"
 property string networkName: "sakura-5g"; property int networkStrength: 80; function wifiIconForStrength(s) { return Icons.wifiHigh; } }""",
}


WALLPAPER = """import QtQuick
Item { id: w; property string source; property real radius; property bool tintEnabled
 readonly property bool isVideo: false; readonly property real videoPosition: 0
 function videoPlayAt(p) {} function videoSeek(p) {} function videoPlay() {}
 Image { anchors.fill: parent; source: w.source; fillMode: Image.PreserveAspectCrop; asynchronous: false
         sourceSize.width: 1920 } }"""

QUICKSHELL_WAYLAND = {
    "WlSessionLockSurface": "Item { width: 1280; height: 720; property var screen: null; property color color }",
    "ScreencopyView": "Item { property var captureSource; property bool live; property bool paintCursor; function captureFrame() {} }",
}
# Fake PAM: asks for the password, succeeds only for "correct".
PAM = {
    "PamResult": "QtObject { enum Values { Success, Failed, Error, MaxTries } }",
    "PamContext": """Item { id: pam; property string configDirectory; property string config; property string message: "Password: "
 property int messageType; property bool responseRequired: true
 property int starts: 0; property string received: "__none__"
 signal pamMessage; signal completed(int result)
 function respond(r) { received = r; }
 function start() { starts++; Qt.callLater(function() { pam.pamMessage(); pam.completed(pam.received === "correct" ? PamResult.Success : PamResult.Failed); }); } }""",
}
GLOBALS = {
    "GlobalStates": """pragma Singleton
QtObject { property bool lockscreenVisible: true; property var wallpaperManager: null; property int videoSyncTick: 0
 function wallpaperForScreen(n) { return null; } }""",
}


class LockscreenEnv(SettingsEnv):
    def __init__(self, name: str = "lockscreen", *, palette: dict | None = None, overrides: dict | None = None):
        # SettingsEnv: real kit (modules/components/kit), StyledRect, Styling,
        # Metrics, Motion, Glass, Icons; generated Config / Colors / I18n.
        super().__init__(name, palette=palette, overrides=overrides)
        qs = self.root / "qs"
        for rel in MIRROR:
            src, dst = REPO / rel, qs / rel
            if src.is_dir():
                shutil.copytree(src, dst, dirs_exist_ok=True)
            else:
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(src, dst)
        self.h.module("qs.modules.services", SERVICES)
        self.h.module("qs.modules.components", {"TintedWallpaper": WALLPAPER})
        self.h.module("qs.modules.corners", {
            "RoundCorner": "Item { enum CornerEnum { TopRight, BottomRight, TopLeft, BottomLeft } property int corner; property real size }"})
        self.h.module("qs.modules.globals", GLOBALS)
        self.h.module("Quickshell.Wayland", QUICKSHELL_WAYLAND)
        self.h.module("Quickshell.Services.Pam", PAM)
        for d in ["modules/lockscreen", "modules/lockscreen/styles"]:
            self.h._write_qmldir(qs / d, "qs." + d.replace("/", "."))
        # Binding/runtime errors of the lock screen files (not just type errors).
        self.errors: list[str] = []
        self._prev = qInstallMessageHandler(self._on_message)

    def _on_message(self, mode, ctx, msg: str) -> None:
        if "/lockscreen/" in msg and any(k in msg for k in ("Error", "rror:", "Unable to assign", "undefined")):
            self.errors.append(msg)
        if self._prev:
            self._prev(mode, ctx, msg)

    def lock_screen(self):
        return self.h.load(self.root / "qs/modules/lockscreen/LockScreen.qml", auto_stub=False)

    @staticmethod
    def player(playing: bool = True, title: str = "Yoru ni Kakeru", artist: str = "YOASOBI") -> str:
        """JS literal of a fake MPRIS player."""
        return "({ trackTitle: %s, trackArtist: %s, isPlaying: %s, length: 260, position: 96, positionChanged: () => 0 })" % (
            json.dumps(title), json.dumps(artist), "true" if playing else "false")
