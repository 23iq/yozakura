"""Offscreen environment for the bar panels (modules/bar, panels engine).

Mirrors the real bar, panel styles, modules, components, frame and notch
into a Harness import tree and generates only the shell singletons, with a
small fixture desktop (workspaces, windows, tray, battery, weather...), so
whole-screen layouts render headless:

    env = PanelsEnv(bar={...}, theme={...}, palette={...})
    scene = env.scene(2560, 1440, wallpaper="/path.jpg")

Used by tests/panels.test.py and tools/render/panels_render.py.
"""
from __future__ import annotations

import json
import os
import shutil
from pathlib import Path

# The desktop's controls style (e.g. KDE's org.kde.desktop) loads plugins on
# the QML loader thread, which deadlocks against PySide's GIL.
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
os.environ.pop("QT_QPA_PLATFORMTHEME", None)

from qmlharness import REPO, Harness  # noqa: I001  (imports headless before PySide6)
from PySide6.QtGui import QImage
from PySide6.QtQuick import QQuickImageProvider
from settings_env import SPECIALS_STUB, DEFAULT_PALETTE, _merge, colors_qml, config_qml, i18n_qml, load_defaults

import panels_stubs as stubs
import timers_stubs

# Repo trees mirrored verbatim (every QML gets a qmldir in its directory)
MIRROR_DIRS = [
    "modules/bar",
    "modules/components",
    "modules/corners",
    "modules/frame",
    "modules/widgets/dashboard/widgets",
]
MIRROR_FILES = [
    "modules/theme/Styling.qml",
    "modules/theme/TypeRoles.js",
    "modules/theme/Icons.qml",
    "modules/theme/BarMetrics.qml",
    "modules/theme/Metrics.qml",
    "modules/theme/DensityMetrics.js",
    "modules/theme/Motion.qml",
    "config/motion/MotionBudget.js",
    "modules/theme/Glass.qml",
    "modules/theme/GlassModel.js",
    "modules/theme/GlassCurve.js",
    "modules/theme/GlassContrast.js",
    "modules/theme/Motion.qml",
    "modules/theme/Metrics.qml",
    "modules/theme/DensityMetrics.js",
    "config/motion/MotionBudget.js",
    "modules/shell/PanelShadows.qml",
    "modules/shell/EdgeService.qml",
    "modules/shell/EdgeLayout.js",
    "modules/shell/LayoutModel.js",
    "modules/notch/NotchReveal.js",
    "modules/services/ShellLayout.qml",
    "modules/notch/Notch.qml",
    "modules/notch/NotchViewTransition.qml",
    "modules/notch/NotchSilhouette.qml",
    "modules/notch/NotchOutline.qml",
    "modules/notch/NotchShape.js",
    "modules/shell/hosts/HostRouter.qml",
    "modules/shell/hosts/HostRouter.js",
    "modules/notch/styles/NotchStyles.js",
    "modules/widgets/dashboard/LauncherButton.qml",
    "modules/widgets/powermenu/PowerButton.qml",
    "modules/widgets/presets/PresetsButton.qml",
    "config/ColorSpec.js",
    "modules/specials/Specials.js",
    "assets/yozakura/yozakura-icon.svg",
]
# Repo files replaced by fixtures (heavy service logic)
OVERRIDES = {
    "modules/bar/workspaces/CompositorData.qml": stubs.COMPOSITOR_DATA,
}

ICON_DIRS = [Path("/usr/share/icons/Papirus/64x64/apps"), Path("/usr/share/icons/hicolor/scalable/apps"),
             Path("/usr/share/icons/hicolor/48x48/apps")]


class IconProvider(QQuickImageProvider):
    """`image://icon/<name>` like Quickshell's, from the installed icon themes."""

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Image)

    def requestImage(self, name, size, requested):  # noqa: N802 (Qt API)
        name = name.split("?")[0]
        for d in ICON_DIRS:
            for ext in (".svg", ".png"):
                p = d / (name + ext)
                if p.exists():
                    img = QImage(str(p))
                    w = requested.width() if requested.width() > 0 else 128
                    h = requested.height() if requested.height() > 0 else 128
                    img = img.scaled(w, h) if not img.isNull() else img
                    size.setWidth(img.width())
                    size.setHeight(img.height())
                    return img
        img = QImage(64, 64, QImage.Format.Format_ARGB32)
        img.fill(0)
        return img


def icon_path(name: str) -> str:
    for d in ICON_DIRS:
        for ext in (".svg", ".png"):
            p = d / (name + ext)
            if p.exists():
                return str(p)
    return ""


class PanelsEnv:
    def __init__(self, name: str = "panels", *, repo: Path = REPO, bar: dict | None = None,
                 theme: dict | None = None, dock: dict | None = None, palette: dict | None = None,
                 notch: dict | None = None, extra: dict | None = None):
        self.repo = Path(repo)
        self.h = Harness(name)
        self.root = self.h.root
        domains = load_defaults()
        if (self.repo / "config/defaults").is_dir() and self.repo != REPO:
            domains = self._defaults_of(self.repo, domains)
        for dom, values in {"bar": bar, "theme": theme, "dock": dock, "notch": notch, **(extra or {})}.items():
            if values:
                domains[dom] = _merge(domains[dom], values) if dom != "bar" else {**domains[dom], **values}
        self.domains = domains
        self.palette = palette or DEFAULT_PALETTE
        self._mirror()
        qs = self.root / "qs"
        top = stubs.config_extra(domains)
        (qs / "config").mkdir(parents=True, exist_ok=True)
        (qs / "config" / "Config.qml").write_text(config_qml(domains, top))
        self._qmldir(qs / "config", "qs.config", only=["Config"])
        (qs / "modules/theme/Colors.qml").write_text(colors_qml(self.palette))
        self._qmldir(qs / "modules/theme", "qs.modules.theme")
        services = {"I18n": i18n_qml(), **stubs.services(icon_path), **timers_stubs.services()}
        timers_stubs.copy_js(self.root)
        self.h.module("qs.modules.services", services)
        self.h.module("qs.modules.globals", {"GlobalStates": stubs.GLOBAL_STATES})
        for module, types in stubs.quickshell_modules(icon_path).items():
            self.h.module(module, types)
        self.h.module("qs.modules.shell.osd.styles", {"OsdBarInline": "Item { property real radius: 0 }"})
        self.h.module("qs.modules.widgets.overview", {"OverviewThumb": "Item {}"})
        self.h.module("qs.modules.specials", {"SpecialsService": SPECIALS_STUB})
        self.h.module("qs.modules.services.activities", {
            "ActivityService": stubs.ACTIVITY_SERVICE,
            "TimerActivity": "pragma Singleton\nQtObject { function attach(t) {} function detach(t) {} }"})
        self.h.engine.addImageProvider("icon", IconProvider())

    @staticmethod
    def _defaults_of(repo: Path, fallback: dict) -> dict:
        import subprocess
        script = """
const q = require(process.argv[1]);
const fs = require('fs'), path = require('path');
const dir = process.argv[2]; const out = {};
for (const f of fs.readdirSync(dir)) if (f.endsWith('.js'))
  out[f.slice(0, -3)] = q.loadLibrary(path.join(dir, f)).data;
console.log(JSON.stringify(out));
"""
        r = subprocess.run(["node", "-e", script, str(REPO / "tests/lib/qmljs.cjs"), str(repo / "config/defaults")],
                           capture_output=True, text=True)
        return json.loads(r.stdout) if r.returncode == 0 else fallback

    def _mirror(self) -> None:
        qs = self.root / "qs"
        for rel in MIRROR_DIRS:
            src = self.repo / rel
            if src.is_dir():
                shutil.copytree(src, qs / rel, dirs_exist_ok=True)
        for rel in MIRROR_FILES:
            src = self.repo / rel
            if src.is_file():
                (qs / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(src, qs / rel)
        for rel, body in OVERRIDES.items():
            (qs / rel).write_text(body)
        for d in sorted({p.parent for p in qs.rglob("*.qml")}):
            rel = d.relative_to(self.root)
            if rel.parts[:2] == ("qs", "config") or d.name == "theme":
                continue
            self._qmldir(d, ".".join(rel.parts))

    def _qmldir(self, d: Path, module: str, only: list[str] | None = None) -> None:
        lines = [f"module {module}"]
        for f in sorted(d.glob("*.qml")):
            if only is not None and f.stem not in only:
                continue
            single = f.read_text().lstrip().startswith("pragma Singleton")
            lines.append(f"{'singleton ' if single else ''}{f.stem} 1.0 {f.name}")
        (d / "qmldir").write_text("\n".join(lines) + "\n")

    def load(self, qml: str):
        return self.h.load(qml, auto_stub=False)

    def scene(self, width: int, height: int, *, wallpaper: str = "", windows: bool = True,
              notch_text: str = "") -> object:
        legacy = not (self.repo / "modules/bar/PanelHost.qml").exists()
        return self.load(stubs.scene_qml(width, height, wallpaper, windows, notch_text, legacy))
