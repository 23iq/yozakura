"""Offscreen environment for the OSD styles (modules/shell/osd).

KitEnv (real kit, StyledRect, Styling, Metrics, Motion, Icons, generated
Config / Colors, I18n) plus the OSD modules `qs.modules.shell.osd` and
`qs.modules.shell.osd.styles`, with idle Audio and OsdService stand-ins.

Used by tools/render/osd_render.py.
"""
from __future__ import annotations

import shutil

from kit_env import KitEnv
from qmlharness import REPO

AUDIO_STUB = """pragma Singleton
import QtQuick
import qs.modules.theme
QtObject {
    function volumeIcon(volume, muted) {
        if (muted) return Icons.speakerX;
        if (volume <= 0) return Icons.speakerNone;
        if (volume < 0.33) return Icons.speakerLow;
        return Icons.speakerHigh;
    }
}"""

OSD_SERVICE_STUB = """pragma Singleton
import QtQuick
QtObject {
    signal level(string kind, real value, bool muted, string device)
    signal inlineRequest(string kind)
    property int timeout: 2500
    property real lastValue: 0
    property string lastScreen: ""
    property bool lastMuted: false
    property int inlineHosts: 0
    property var adjusted: []
    function registerInline(on, screenName) { inlineHosts += on ? 1 : -1 }
    function adjust(kind, delta, screen) { adjusted = adjusted.concat([[kind, delta]]) }
    function currentDevice(kind) { return kind === "mic" ? "Built-in Microphone" : "Speakers" }
}"""


class OsdEnv(KitEnv):
    def __init__(self, name: str = "osd", **kw):
        super().__init__(name, **kw)
        qs = self.root / "qs"
        dst = qs / "modules/shell/osd"
        shutil.copytree(REPO / "modules/shell/osd", dst, dirs_exist_ok=True)
        self._qmldir(dst, "qs.modules.shell.osd")
        self._qmldir(dst / "styles", "qs.modules.shell.osd.styles")
        self.h.module("qs.modules.services", {"Audio": AUDIO_STUB, "OsdService": OSD_SERVICE_STUB})
