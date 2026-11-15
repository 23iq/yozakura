"""Material You palettes from a wallpaper without matugen, for offscreen renders.

The render tools take the palette from matugen when it is installed (the
same tool the shell uses). On a machine without it (CI, a sandbox) a proof
render used to fall back to the fixed rose palette whatever the wallpaper,
which pairs badly with most images. This module derives the palette from the
wallpaper with the `materialyoucolor` package (the Material Color Utilities
port matugen is built on: Celebi quantization, scoring, dynamic schemes), so
wallpaper and colours belong together. Install it with
`uv pip install materialyoucolor` (or `pip install --user materialyoucolor`);
`available()` says whether it can be used.

    palette(image, "dark")            -> {shell role: "#rrggbb"} (Colors names)
    scheme_previews(image)            -> {"scheme-tonal-spot": {"dark": {...}, "light": {...}}, ...}
"""
from __future__ import annotations

import importlib.util
from functools import lru_cache

# matugen scheme name -> materialyoucolor scheme module / class
SCHEMES = {
    "scheme-content": ("scheme_content", "SchemeContent"),
    "scheme-expressive": ("scheme_expressive", "SchemeExpressive"),
    "scheme-fidelity": ("scheme_fidelity", "SchemeFidelity"),
    "scheme-fruit-salad": ("scheme_fruit_salad", "SchemeFruitSalad"),
    "scheme-monochrome": ("scheme_monochrome", "SchemeMonochrome"),
    "scheme-neutral": ("scheme_neutral", "SchemeNeutral"),
    "scheme-rainbow": ("scheme_rainbow", "SchemeRainbow"),
    "scheme-tonal-spot": ("scheme_tonal_spot", "SchemeTonalSpot"),
}

# The roles the shell reads (modules/theme/Colors.qml names: on* -> over*).
ROLES = [
    "background", "surface", "surfaceDim", "surfaceBright", "surfaceContainerLowest", "surfaceContainerLow",
    "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceVariant", "surfaceTint",
    "primary", "onPrimary", "primaryContainer", "onPrimaryContainer", "secondary", "onSecondary",
    "secondaryContainer", "onSecondaryContainer", "tertiary", "onTertiary", "tertiaryContainer",
    "onTertiaryContainer", "onBackground", "onSurface", "onSurfaceVariant", "outline", "outlineVariant",
    "error", "onError", "errorContainer", "onErrorContainer", "inverseSurface", "inverseOnSurface",
    "inversePrimary", "shadow", "scrim",
]
# the scheme picker's preview roles (backend cmds_schemes.go schemePreviewRoles)
PREVIEW_ROLES = [
    "primary", "onPrimary", "primaryContainer", "onPrimaryContainer", "secondary", "secondaryContainer",
    "tertiary", "tertiaryContainer", "background", "onBackground", "surface", "surfaceDim", "surfaceBright",
    "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "onSurface",
    "onSurfaceVariant", "outline", "outlineVariant", "error",
]


def available() -> bool:
    return importlib.util.find_spec("materialyoucolor") is not None


def shell_name(role: str) -> str:
    return "over" + role[2:] if role.startswith("on") and role[2:3].isupper() else role


@lru_cache(maxsize=8)
def seed(image: str) -> int:
    """The wallpaper's source colour (ARGB int), as matugen picks it."""
    from PIL import Image
    from materialyoucolor.quantize import QuantizeCelebi
    from materialyoucolor.score.score import Score

    im = Image.open(image).convert("RGB")
    im.thumbnail((128, 128))
    pixels = [(r, g, b, 255) for r, g, b in im.get_flattened_data()] if hasattr(im, "get_flattened_data") \
        else [(r, g, b, 255) for r, g, b in im.getdata()]
    return Score.score(QuantizeCelebi(pixels, 128))[0]


def _hex(argb: int) -> str:
    return "#%06x" % (argb & 0xFFFFFF)


def _scheme(image: str, mode: str, scheme: str):
    import importlib

    from materialyoucolor.hct import Hct

    module, cls = SCHEMES.get(scheme, SCHEMES["scheme-tonal-spot"])
    klass = getattr(importlib.import_module("materialyoucolor.scheme." + module), cls)
    return klass(Hct.from_int(seed(image)), mode == "dark", 0.0)


def _roles(image: str, mode: str, scheme: str, roles: list[str]) -> dict:
    from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors

    s = _scheme(image, mode, scheme)
    out = {}
    for role in roles:
        color = getattr(MaterialDynamicColors, role, None)
        if color is not None:
            out[shell_name(role)] = _hex(color.get_argb(s))
    return out


def palette(image: str, mode: str, scheme: str = "scheme-tonal-spot") -> dict:
    """The shell palette (Colors names) of `image` in `mode` ("dark" | "light")."""
    return _roles(image, mode, scheme, ROLES)


def scheme_previews(image: str) -> dict:
    """What `yozakura schemes <image>` returns under "schemes", for the picker."""
    return {name: {mode: _roles(image, mode, name, PREVIEW_ROLES) for mode in ("dark", "light")}
            for name in SCHEMES}
