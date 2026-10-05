"""Glass system in QML, offscreen: the Glass singleton drives StyledRect
(opacity, tint, highlight, per-surface roots), the legibility floor holds,
the settings Glass section (master slider, follow-preset chip, collapsible
advanced section, per-surface editor) writes theme.glass.* and the preview
reports the guaranteed contrast.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv, load_defaults  # noqa: E402

# A translucent preset (popup 0.9, pane 0.78) like Sakura Glass.
_theme = load_defaults()["theme"]
OVERRIDES = {"theme": {"srPopup": dict(_theme["srPopup"], opacity=0.9), "srPane": dict(_theme["srPane"], opacity=0.78)}}
env = SettingsEnv("glass", overrides=OVERRIDES, wallpaper={"dir": "/walls", "paths": [], "current": ""})
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
import qs.modules.settings
Window {
    id: w
    width: 1000; height: 900; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function setGlass(patch) { Config.theme.glass = Object.assign({}, Config.theme.glass, patch) }
    function setSurface(name, amount) {
        const g = JSON.parse(JSON.stringify(Config.theme.glass));
        g.surfaces[name].amount = amount;
        Config.theme.glass = g;
    }
    Row {
        StyledRect { objectName: "popup"; variant: "popup"; width: 120; height: 80 }
        StyledRect { objectName: "popupRoot"; variant: "popup"; glassSurface: "popups"; width: 120; height: 80 }
        StyledRect { objectName: "pane"; variant: "pane"; width: 120; height: 80 }
        StyledRect { objectName: "primary"; variant: "primary"; width: 120; height: 80 }
    }
    SettingsShell { objectName: "shell"; y: 100; width: 1000; height: 800 }
}""")
h.eval(h.find(win, "shell"), 'select("appearance")')


def ev(expr):
    return h.eval(win, expr)


def settle(ms=150):
    QTest.qWait(ms)


def op(name):
    return ev(f'w.findItem("{name}").rectOpacity')


# Native (amount -1): the preset's own opacities, no tint/highlight.
settle(400)
check(abs(op("popup") - 0.9) < 1e-6, f"native popup opacity {op('popup')}")
check(abs(op("pane") - 0.78) < 1e-6, f"native pane opacity {op('pane')}")
check(ev('w.findItem("popupRoot").glassHighlight') == 0, "no highlight at the preset's amount")
ref = ev("Glass.reference")
check(0 < ref < 1, f"reference derived from the preset: {ref}")

# Solid at 0, glassier at 1 but never below the legibility floor.
ev("w.setGlass({ amount: 0 })")
settle()
check(op("popup") == 1 and op("pane") == 1, "amount 0 is solid")
ev("w.setGlass({ amount: 1 })")
settle()
floor = ev('Glass.floors["popup"]')
check(op("popup") < 0.9, "amount 1 is glassier than the preset")
check(op("popup") >= floor - 1e-9, f"popup {op('popup')} >= legibility floor {floor}")
check(ev('Glass.worstContrast("popup", w.findItem("popup").rectOpacity)') >= 4.5 - 1e-6, "WCAG AA on any wallpaper")
check(ev('w.findItem("popupRoot").glassHighlight') > 0, "glass roots draw the top-edge highlight")
check(ev('w.findItem("popup").glassTint') > 0, "palette tint above the preset's amount")
check(op("primary") == 1, "accent variants are not glass")

# Per-surface override: only the popups root follows it.
ev('w.setSurface("popups", 0)')
settle()
check(op("popupRoot") == 1, "popups surface override (solid)")
check(op("popup") < 1, "other rects keep the master amount")

# Off: everything solid.
ev("w.setGlass({ enabled: false })")
settle()
check(op("popup") == 1 and op("popupRoot") == 1 and op("pane") == 1, "glass off is solid")
check(ev("Glass.shellBlur") is False, "glass off drops the shell layer blur")
ev("w.setGlass({ enabled: true, amount: -1 })")
ev('w.setSurface("popups", -1)')
settle()

# Settings: master slider writes the amount, the chip goes back to the preset.
slider = ev('w.findItem("glassAmountSlider")')
check(slider is not None, "glass amount slider rendered")
check(abs(ev('w.findItem("glassAmountSlider").value') - round(ref * 100)) < 1e-6, "slider shows the preset's amount")
ev('w.findItem("glassAmountSlider").moved(70)')
settle()
check(abs(ev("Config.theme.glass.amount") - 0.7) < 1e-6, "slider writes theme.glass.amount")
ev('w.findItem("glassFollowPreset").children[1].clicked(null)')
settle()
check(ev("Config.theme.glass.amount") == -1, "chip resets to the preset's amount")

# Advanced section is folded; a search jump unfolds it.
adv = ev('w.findItem("settingsSection:glassAdvanced")')
check(adv is not None and ev('w.findItem("settingsSection:glassAdvanced").expanded') is False, "advanced folded")
ev('w.findItem("settingsSection:glassAdvanced").rowFor("theme.glass.advanced.blurSize")')
check(ev('w.findItem("settingsSection:glassAdvanced").expanded') is True, "rowFor unfolds the section")

# Per-surface editor writes the override.
ev('w.findItem("settingsSection:glassSurfaces").expanded = true')
settle()
check(ev('w.findItem("glassSurface:dock") !== null'), "surface rows rendered")
ev('w.findItem("glassSurface:dock").children[0].toggled(true)')
settle()
check(abs(ev("Config.theme.glass.surfaces.dock.amount") - round(ref, 2)) < 0.011, "surface toggle pins the current amount")

# Preview contrast readout.
check(ev('w.findItem("glassContrast") !== null'), "preview contrast readout rendered")
check("4.5" in ev('w.findItem("glassContrast").text') or ev('w.findItem("glassContrast").text').startswith("Text contrast"),
      "contrast readout text")

print("glass:", "ok" if not failures else f"{len(failures)} failure(s)")
sys.exit(1 if failures else 0)
