"""Surface effects in QML, offscreen (theme.surfaceEffect, registry
modules/components/surfaceeffects): "none" creates nothing, crt/ink load
their overlay on shell surface roots only (glassSurface / effectSurface),
ink paints highlight rects as brush strokes (opt-out, size floor, option),
the overlay really draws (static scanlines, paper grain) and the settings
cards / indicator chips render every registered entry.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("surface-effects", wallpaper={"dir": "/walls", "paths": [], "current": ""})
h = env.h
failures: list[str] = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.components.surfaceeffects
import qs.modules.settings
Window {
    id: w
    width: 900; height: 900; visible: true; color: "black"
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function loader(rect, name) {
        var kids = findItem(rect).children;
        for (var i = 0; i < kids.length; i++) if (kids[i].objectName === name) return kids[i];
        return null;
    }
    function effect(rect) { return findItem(rect).effectOverlay ? loader(rect, "surfaceEffect").item : null }
    function highlight(rect) { return findItem(rect).effectFill ? loader(rect, "surfaceEffect").item : null }
    function loaded(rect) { var l = loader(rect, "surfaceEffect"); return l.active && l.item !== null }
    function setEffect(id, opts) {
        Config.theme.surfaceEffect = id;
        if (opts) Config.theme.surfaceEffectOptions = Object.assign({}, Config.theme.surfaceEffectOptions, opts);
    }
    Column {
        Row {
            StyledRect { objectName: "barRoot"; variant: "bg"; glassSurface: "bar"; width: 300; height: 60; enableBorder: false
                         topLeftRadius: 0; topRightRadius: 0; bottomLeftRadius: 0; bottomRightRadius: 0; radius: 0 }
            StyledRect { objectName: "popupInner"; variant: "popup"; width: 120; height: 60 }
            StyledRect { objectName: "modulePill"; variant: "bg"; effectSurface: "bar"; width: 120; height: 60 }
            StyledRect { objectName: "lockRoot"; variant: "bg"; glassSurface: "lockscreen"; width: 120; height: 60 }
        }
        Row {
            StyledRect { objectName: "selection"; variant: "primary"; width: 160; height: 32 }
            StyledRect { objectName: "focusRow"; variant: "focus"; width: 160; height: 32 }
            StyledRect { objectName: "optOut"; variant: "primary"; effectHighlight: false; width: 160; height: 32 }
            StyledRect { objectName: "tinyDot"; variant: "primary"; width: 8; height: 8 }
            StyledRect { objectName: "paneRow"; variant: "pane"; width: 160; height: 32 }
        }
        SettingsShell { objectName: "shell"; width: 900; height: 760 }
    }
}""")
shell = h.find(win, "shell")


def ev(expr):
    return h.eval(win, expr)


def settle(ms=200):
    QTest.qWait(ms)


def row_profile(name: str) -> list[int]:
    """Red channel down the middle column of a rect in the grabbed window."""
    img = win.grabWindow()
    x = int(ev(f'w.findItem("{name}").mapToItem(null, 150, 0).x'))
    y0 = int(ev(f'w.findItem("{name}").mapToItem(null, 0, 0).y'))
    return [img.pixelColor(x, y).red() + img.pixelColor(x, y).green() + img.pixelColor(x, y).blue()
            for y in range(y0 + 14, y0 + 46)]


# none: nothing is created, highlight rects keep their own fill
settle()
check(ev("SurfaceFx.effectId") == "none", "default effect is none")
for name in ["barRoot", "modulePill", "selection", "focusRow"]:
    check(not ev(f'loaded("{name}")'), f"none creates no loader item ({name})")
check(ev('w.findItem("selection").color.a') > 0.5, "selection keeps its fill with none")
flat = row_profile("barRoot")
check(max(flat) - min(flat) <= 3, f"no texture with none: {min(flat)}..{max(flat)}")

# crt: overlay on surface roots and bar module pills, never elsewhere
ev('setEffect("crt", { intensity: 0.8 })')
settle(500)
check(ev('effect("barRoot") !== null && loaded("barRoot")'), "crt loads on a bar surface root")
check(ev('effect("modulePill") !== null'), "crt loads on a bar module pill (effectSurface)")
check(not ev('loaded("popupInner")'), "crt skips plain (non-surface) rects")
check(not ev('loaded("lockRoot")'), "crt skips non-shell surfaces (lockscreen)")
check(not ev('loaded("selection")'), "crt has no highlight fill")
check(abs(ev('effect("barRoot").strength') - 0.8) < 1e-6, "crt strength = intensity on a legible palette")
check(ev('effect("barRoot").flash') >= 0, "crt exposes its flicker state")
scan = row_profile("barRoot")
# static scanlines: a 3 px periodic pattern down the surface
# (the vignette/bloom add a smooth gradient: the darkest row of every
# 3-row window sits at the same phase)
phases = {min(range(i, i + 3), key=lambda k: scan[k]) % 3 for i in range(0, len(scan) - 2, 3)}
check(max(scan) - min(scan) >= 6, f"crt draws scanlines: {scan}")
check(len(phases) == 1, f"crt scanlines repeat every 3 rows: {scan}")

# ink: grain on surfaces + brush-stroke highlights
ev('setEffect("ink", { intensity: 1, grain: 1, brushHighlights: true })')
ev("Config.theme.lightMode = true")
settle(500)
check(ev('effect("barRoot") !== null'), "ink loads on surfaces")
for name in ["selection", "focusRow"]:
    check(ev(f'highlight("{name}") !== null && loaded("{name}")'), f"ink paints {name} as a brush stroke")
    check(ev(f'w.findItem("{name}").color.a') == 0, f"{name} hands its fill to the stroke")
    check(ev(f'highlight("{name}").fillColor.a') > 0.5, f"the stroke uses {name}'s fill color")
check(not ev('loaded("optOut")') and ev('w.findItem("optOut").color.a > 0.5'), "effectHighlight: false opts out")
check(not ev('loaded("tinyDot")'), "tiny rects keep their plain fill")
check(not ev('loaded("paneRow")'), "non-highlight variants keep their fill")
grain = row_profile("barRoot")
check(max(grain) - min(grain) >= 3, f"ink draws paper grain: {grain}")
ev('setEffect("ink", { brushHighlights: false })')
settle()
check(not ev('loaded("selection")') and ev('w.findItem("selection").color.a > 0.5'), "brushHighlights off restores fills")

# back to none: everything is torn down
ev('setEffect("none")')
ev("Config.theme.lightMode = false")
settle()
check(not ev('loaded("barRoot")') and not ev('loaded("modulePill")'), "switching to none unloads overlays")

# settings: effect cards and indicator chips cover the registries
h.eval(shell, 'select("appearance")')
settle(600)
for eid in ["none", "crt", "ink"]:
    check(ev(f'w.findItem("effectPanel:{eid}") !== null'), f"effect card for {eid}")
h.eval(shell, 'select("bar")')
settle(600)
for sid in ["pill", "underline", "dot", "brush", "bracket"]:
    check(ev(f'w.findItem("indicatorChip:{sid}") !== null'), f"indicator chip for {sid}")
ev('w.findItem("indicatorChip:bracket").children[w.findItem("indicatorChip:bracket").children.length - 1].clicked(null)')
settle()
check(ev("Config.workspaces.indicatorStyle") == "bracket", "clicking a chip sets workspaces.indicatorStyle")

errors = [e for e in h.type_errors if "surfaceeffects" in e or "indicators" in e or "StyledRect" in e]
check(not errors, f"no QML errors: {errors}")
if failures:
    print(f"surface-effects: {len(failures)} failure(s)")
    sys.exit(1)
print("surface-effects: ok", flush=True)
