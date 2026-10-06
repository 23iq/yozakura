"""Offscreen environment for the shared UI kit (modules/components/kit).

SettingsEnv (real StyledRect, Styling, Metrics, Motion, Icons, generated
Config / Colors) plus the `qs.modules.components.kit` module and, for
renders, the gallery sheet (tools/render/KitGallery*.qml) as `qs.kitgallery`.

Used by tests/kit.test.py and tools/render/kit_render.py.
"""
from __future__ import annotations

import shutil

from qmlharness import REPO  # first: enters the headless platform
from settings_env import SettingsEnv

LANGUAGES = ["ink", "glass", "tiles"]


class KitEnv(SettingsEnv):
    def __init__(self, name: str = "kit", *, gallery: bool = False, **kw):
        super().__init__(name, **kw)
        qs = self.root / "qs"
        self._qmldir(qs / "modules/components/kit", "qs.modules.components.kit")
        if gallery:
            dst = qs / "kitgallery"
            dst.mkdir(parents=True, exist_ok=True)
            for f in (REPO / "tools/render").glob("KitGallery*.qml"):
                shutil.copy(f, dst / f.name)
            self._qmldir(dst, "qs.kitgallery")
