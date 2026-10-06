"""Settings preset studio (modules/settings/presets), offscreen, end to end.

The real SettingsShell runs in a private Xvfb (tests/lib/settings_env.py)
and the studio store runs the real `<app> preset` CLI of this checkout in a
sandboxed HOME (tests/lib/preset_sandbox.py). Checks: gallery cards and
filters, thumbnails rendered and cached, apply, a timed trial that reverts
by itself, duplicate through the name dialog (validation included), the
editor (aspects vs defaults, read-only built-ins, jump into settings starts
an edit session, the banner saves into the preset), delete with undo, the
mixer and import.
"""
import json
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from preset_sandbox import PresetSandbox  # noqa: E402
from settings_env import BRAND_CACHE, SettingsEnv  # noqa: E402

errors: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "Unable to assign",
                              "failed to load", "Error:", "overrides a member", "is overridden")):
        errors.append(msg)
    if _prev:
        _prev(mode, ctx, msg)
    elif "Cannot open" not in msg:
        print(msg, file=sys.stderr)


qInstallMessageHandler(_capture)

sb = PresetSandbox(Path(tempfile.mkdtemp(prefix="preset-studio-test-")))
env = SettingsEnv("preset-studio", wallpaper={"dir": "/walls", "paths": [], "current": ""})
h = env.h
shutil.rmtree(BRAND_CACHE / "preset-thumbs", ignore_errors=True)  # fresh: thumbnails must render
(BRAND_CACHE / "preset-thumbs").mkdir(parents=True)
bridge = sb.bridge()
h.engine.rootContext().setContextProperty("presetBridge", bridge)
win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.globals
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1280; height: 900; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function countPrefix(prefix, from) {
        var item = from || w.contentItem, n = item.objectName && item.objectName.indexOf(prefix) === 0 && item.visible ? 1 : 0;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) n += countPrefix(prefix, kids[i]);
        return n;
    }
    function pg() { return findItem("settingsPage").item; }
    function cur() { return pg().current; }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")
failures: list[str] = []


def check(ok, what):
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


def ev(expr, obj=None):
    return h.eval(obj or shell, expr)


def w(expr):
    """Evaluate in the test window: pg() = studio page, cur() = its view,
    findItem(name). Python never keeps wrappers of QML items that the
    studio destroys (PySide would hand back stale ones)."""
    return ev(expr, win)


def wait_for(expr, ms=8000, obj=None):
    for _ in range(ms // 50):
        if ev(expr, obj):
            return True
        QTest.qWait(50)
    return False


def calls_with(*prefix):
    return [c for c in sb.calls if c[:len(prefix)] == list(prefix)]


ev("PresetStudio.runner = function (a, cb) { var r = presetBridge.run(a); cb(r[0], r[1], r[2]); }")
ev("PresetStudio.trialSeconds = 1")
ev('select("presets")')
check(wait_for("PresetStudio.loaded"), "the studio loads the preset list through the CLI")
listed = sb.json("list", "--json")
QTest.qWait(300)
check(w('countPrefix("presetCard:")') == len(listed), f"one card per preset ({len(listed)})")
check(ev("PresetStudio.aspects.length") == 6, "aspects come from `preset aspects`")

# Filters / search
w('cur().filter = "light"')
QTest.qWait(100)
light = [p for p in listed if p["look"]["theme.lightMode"]]
check(w('countPrefix("presetCard:")') == len(light), "the light filter shows light presets only")
w('cur().filter = "all"')
w('cur().query = "neon"')
QTest.qWait(100)
check(w('countPrefix("presetCard:")') == 1, "search narrows the gallery")
w('cur().query = ""')
QTest.qWait(100)

# Thumbnails: rendered lazily, saved to the cache
thumbs = BRAND_CACHE / "preset-thumbs"
for _ in range(160):
    if len(list(thumbs.glob("*.png"))) >= 2:
        break
    QTest.qWait(50)
check(len(list(thumbs.glob("*.png"))) >= 2, "thumbnails are rendered and cached as PNGs")
check(ev("PresetStudio.rendering <= PresetStudio.maxRendering"), "thumbnail rendering is throttled")

# Apply
w('pg().handle("Neon Tokyo", "apply")')
check(wait_for('PresetStudio.active === "Neon Tokyo"'), "apply goes through `preset apply` and marks it active")
check(calls_with("apply", "Neon Tokyo") != [], "apply ran the CLI")

# Trial: a double click starts one trial only (pending guard), then the
# countdown pill shows and the trial reverts by itself
ev("""(function () {
    var held = [];
    PresetStudio.runner = function (a, cb) {
        if (a[0] === "__flush") {
            var q = held; held = [];
            q.forEach(function (h) { var r = presetBridge.run(h[0]); h[1](r[0], r[1], r[2]); });
            PresetStudio.runner = function (a2, cb2) { var r2 = presetBridge.run(a2); cb2(r2[0], r2[1], r2[2]); };
            return;
        }
        if (a[0] === "try" && a.length === 2) { held.push([a, cb]); return; }
        var r = presetBridge.run(a); cb(r[0], r[1], r[2]);
    };
})()""")
w('pg().handle("Sumi-e", "try")')
w('pg().handle("Sumi-e", "try")')
check(ev('PresetStudio.pending === "Sumi-e"'), "a running try marks the preset pending")
ev('PresetStudio.runner(["__flush"], null)')
check(len(calls_with("try", "Sumi-e")) == 1, f"a second try while one is pending is ignored ({len(calls_with('try', 'Sumi-e'))} runs)")
check(wait_for("PresetStudio.trial !== null"), "try starts a trial")
check(w('findItem("presetTrialPill").shown'), "the countdown pill shows")
check(sb.run(["active"])[1].strip() == "Sumi-e", "the tried preset is applied")
check(wait_for("PresetStudio.trial === null", 4000), "the trial ends by itself")
check(calls_with("try", "--revert") != [], "…by reverting")
check(sb.run(["active"])[1].strip() == "Neon Tokyo", "the previous preset is back")

# Duplicate through the name dialog
w('pg().handle("Neon Tokyo", "duplicate")')
QTest.qWait(400)
check(w('findItem("presetNameField").visible'), "duplicate asks for a name")
w('findItem("presetNameField").input.text = "sumi-e"')
QTest.qWait(50)
check(not w('findItem("presetNameConfirm").enabled'), "a built-in name is refused in the dialog")
w('findItem("presetNameField").input.text = "Neon Mine"')
QTest.qWait(50)
check(w('findItem("presetNameConfirm").enabled'), "a free name is accepted")
w('findItem("presetNameConfirm").clicked()')
check(wait_for('pg().view === "editor" && pg().editing === "Neon Mine"', obj=win), "duplicating opens the copy in the editor")
check(wait_for("cur().inspection !== null", obj=win), "the editor inspects the preset (`preset show`)")
check(not w("cur().official"), "the copy is editable")
check(w('findItem("editorEditLive").visible'), "user presets offer live editing")

# Jump into settings: starts an edit session
w('cur().edit("bar", "placement", "")')
check(wait_for("PresetStudio.edit !== null"), "jumping from the editor starts an edit session")
check(ev("currentCategory") == "bar", "…and opens the aspect's settings page")
check(w('findItem("presetEditBanner").shown'), "the editing banner shows on settings pages")
check(sb.run(["edit", "--status", "--json"])[1].find('"preset": "Neon Mine"') != -1, "the backend session edits Neon Mine")
# A change made while editing (as the settings pages write the live files)
cfg = sb.config_dir / "config" / "theme.json"
theme = json.loads(cfg.read_text())
theme["roundness"] = 3
cfg.write_text(json.dumps(theme))
ev("PresetStudio.finishEdit(true, false)")
check(wait_for("PresetStudio.edit === null"), "Save ends the edit session")
mine = sb.json("show", "Neon Mine", "--json", "--against", "Neon Tokyo")
changed = [c["key"] for a in mine["aspects"] for c in a["changes"]]
check(changed == ["theme.roundness"], f"the edit went into the preset ({changed})")
check(sb.run(["active"])[1].strip() == "Neon Tokyo", "the look from before the edit is back")

# Built-in editor is read-only
ev('select("presets")')
QTest.qWait(300)
w('pg().show("editor:Sumi-e")')
check(wait_for("cur().inspection !== null", obj=win), "a built-in preset opens in the editor")
check(w("cur().official") and not w('findItem("editorEditLive").visible'), "built-ins cannot be edited live")

# Delete with undo
w('pg().handle("Neon Mine", "delete")')
check(wait_for('PresetStudio.find("Neon Mine") === null'), "delete removes the preset")
check(wait_for('PresetStudio.toast !== null && PresetStudio.toast.undo !== ""'), "the toast offers undo")
ev("PresetStudio.undoDelete(PresetStudio.toast.undo)")
check(wait_for('PresetStudio.find("Neon Mine") !== null'), "undo restores it")

# Mixer
w('pg().show("mixer")')
check(wait_for("Object.keys(cur().sources).length === 6", obj=win), "the mixer starts with a source per aspect")
w('cur().sources = ' + json.dumps({"layout": "Kaze", "colors": "Neon Tokyo", "windows": "CRT", "desktop": "Sumi-e",
                                   "lockscreen": "Neon Mine"}))
QTest.qWait(50)
check(w('cur().look["bar.panels"][0].edge') == "left", "the preview composes the layout source")
check(w('cur().look["theme.oledMode"]') is True, "…and the colors source")
w('cur().askName("Blend", cur().sources)')
QTest.qWait(100)
w('findItem("presetNameField").input.text = "Blend"')
QTest.qWait(50)
w('findItem("presetNameConfirm").clicked()')
check(wait_for('PresetStudio.find("Blend") !== null'), "create saves the mix (`preset mix`)")
mix = calls_with("mix", "Blend")
check(mix and "--layout" in mix[0] and "Kaze" in mix[0], f"mix sends each aspect source ({mix[:1]})")
blend = next(p for p in sb.json("list", "--json") if p["name"] == "Blend")
check(blend["look"]["bar.panels"][0]["edge"] == "left" and blend["look"]["theme.oledMode"] is True, "the saved mix has the previewed look")

# Save the current look, import a bundle
ev('PresetStudio.saveCurrent("Snapshot")')
check(wait_for('PresetStudio.find("Snapshot") !== null'), "save current look creates a user preset")
bundle = Path(tempfile.mkdtemp()) / "shared.json"
sb.run(["export", "Blend", str(bundle)])
data = json.loads(bundle.read_text())
data["name"] = "Shared"
bundle.write_text(json.dumps(data))
ev(f'PresetStudio.importFile("file://{bundle}")')
check(wait_for('PresetStudio.find("Shared") !== null'), "importing a bundle (file URL as dropped) adds the preset")

check(not errors, "no QML errors: " + "; ".join(errors[:5]))
print(f"{len(failures)} failure(s)")
h.exit(1 if failures else 0)
