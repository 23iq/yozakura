"""Layouts of the bar render matrix (tools/render/panels_render.py --bar-matrix).

Every bar style (bar.layout.style) on the top and the left edge in each kit
language, cropped to the bar strip, plus every bar popup opened from a top
classic bar: bar-<style>-<edge>-<language>.png and
bar-popup-<popup>-<language>.png.
"""
from __future__ import annotations

STYLES = ["classic", "floating", "islands", "pills", "dock-like"]
EDGES = ["top", "left"]
LANGUAGES = ["ink", "glass", "tiles"]

START = ["launcher", "workspaces", "layoutSelector", "appMenu"]
END = ["downloads", "systray", "controls", "battery", "clock", "power"]

# The strip around an edge, in px of a 1600x900 scene
STRIP = 96

# popup id -> (the module, its BarPopup); renders call open() on the popup
POPUPS = {
    "battery": ("batteryModule", "batteryPopup"),
    "controls": ("controlsModule", "controlsPopup"),
    "layout": ("layoutSelectorModule", "layoutPopup"),
    "appmenu": ("appMenu", "appMenuPopup"),
    "downloads": ("downloads", "downloadsPopup"),
    "systray": ("trayItem", "systrayMenu"),
}


def _bar(style: str, edge: str) -> dict:
    return {
        "position": edge,
        "frameEnabled": False,
        "containBar": False,
        "pinnedOnStartup": True,
        "layout": {"style": style, "left": START, "right": END, "drawer": []},
        "panels": [],
    }


def _theme(language: str, surface: bool) -> dict:
    theme = {"language": language}
    if surface:
        # A visible strip: the groups inside it take the language's look
        # (sr* variants are replaced whole, not merged)
        theme["srBarBg"] = {
            "label": "Bar BG", "gradient": [["surfaceDim", 0.0]], "gradientType": "linear", "gradientAngle": 0,
            "gradientCenterX": 0.5, "gradientCenterY": 0.5, "halftoneDotMin": 0.0, "halftoneDotMax": 2.0,
            "halftoneStart": 0.0, "halftoneEnd": 1.0, "halftoneDotColor": "surface",
            "halftoneBackgroundColor": "surfaceDim", "border": ["surfaceBright", 0], "itemColor": "overBackground",
            "opacity": 0.92,
        }
    return theme


def strips(surface: bool = False) -> list[dict]:
    out = []
    suffix = "-surface" if surface else ""
    for style in STYLES:
        for edge in EDGES:
            for lang in LANGUAGES:
                out.append({
                    "name": f"bar-{style}-{edge}-{lang}{suffix}",
                    "label": f"{style} · {edge} · {lang}",
                    "bar": _bar(style, edge),
                    "theme": _theme(lang, surface),
                    "crop": {"edge": edge, "size": STRIP},
                })
    return out


def popups(surface: bool = False) -> list[dict]:
    out = []
    suffix = "-surface" if surface else ""
    for pid, (obj, popup) in POPUPS.items():
        for lang in LANGUAGES:
            out.append({
                "name": f"bar-popup-{pid}-{lang}{suffix}",
                "label": f"{pid} popup · {lang}",
                "bar": _bar("classic", "top"),
                "theme": _theme(lang, surface),
                "actions": [{"object": popup, "eval": "open()", "wait": 700}],
                "crop": {"around": [obj, popup], "pad": 24},
            })
    return out
