#!/usr/bin/env python3
"""Static color presets of the built-in preset palettes (assets/colors/<Name>/).

    python3 tools/colors/palettes.py [NAME ...]

Each palette is a seed color + a matugen scheme, run through the shell's own
matugen config (assets/matugen/config.toml: material roles plus the blended
terminal colors) and mapped like the colors.json template (camelCase, on_ ->
over, background lightened -2.5, lightRed... = red lightened 5). The
palette's hand-tuned overrides then set what the concept needs (a near-black
ground, phosphor text, cream paper...). Writes dark.json / light.json (the 98
keys Colors.qml reads) and the 8-line dark / light files (background, red,
green, yellow, blue, magenta, cyan, foreground) next to them.
"""
import colorsys
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets" / "colors"
CONFIG = REPO / "assets" / "matugen" / "config.toml"
TERMINAL = ["red", "green", "yellow", "blue", "magenta", "cyan"]
SURFACES = ["surfaceContainerLowest", "background", "surfaceDim", "surface", "surfaceContainerLow",
            "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceBright", "surfaceVariant"]
STEPS = [-1.5, 0, 0, 2, 3, 5, 8, 11, 14, 16]


def lighten(hex_color: str, amount: float) -> str:
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, lum, s = colorsys.rgb_to_hls(r, g, b)
    lum = min(1.0, max(0.0, lum + amount / 100))
    return "#" + "".join(f"{round(c * 255):02x}" for c in colorsys.hls_to_rgb(h, lum, s))


def ramp(base: str, light: bool) -> dict:
    """The surface ladder from one ground color (lighter going up in dark mode, darker in light)."""
    sign = -1 if light else 1
    return {k: lighten(base, sign * step) for k, step in zip(SURFACES, STEPS, strict=True)}


def camel(key: str) -> str:
    if key.startswith("on_"):
        key = "over_" + key[3:]
    head, *rest = key.split("_")
    return head + "".join(w.capitalize() for w in rest)


def material(seed: str, scheme: str, mode: str) -> dict:
    r = subprocess.run(["matugen", "color", "hex", seed, "--dry-run", "-q", "-j", "hex", "-t", scheme,
                        "-c", str(CONFIG)], capture_output=True, text=True, check=True)
    colors = {camel(k): v[mode]["color"] for k, v in json.loads(r.stdout)["colors"].items()}
    colors["background"] = lighten(colors["background"], -2.5)
    for t in TERMINAL:
        colors["light" + t.capitalize()] = lighten(colors[t], 5.0)
    return colors


# name: seed, scheme, overrides per mode ("ground" = the surface ladder base).
PALETTES = {
    "Plum": {"seed": "#c2578a", "scheme": "scheme-content",
             "dark": {"ground": "#1d1219", "primary": "#f2a7c8", "tertiary": "#e7b7d8"},
             "light": {"ground": "#fbf0f4", "primary": "#9c3d68", "tertiary": "#7d4a72"}},
    "Violet Night": {"seed": "#8b5cf6", "scheme": "scheme-fidelity",
                     "dark": {"ground": "#0b0a10", "primary": "#b79cff", "tertiary": "#e8b3ff", "surfaceTint": "#b79cff",
                              "shadow": "#2a1a5e"},
                     "light": {"ground": "#f6f3fb", "tertiary": "#7b3fa0"}},
    "Phosphor": {"seed": "#33ff77", "scheme": "scheme-fidelity",
                 "dark": {"ground": "#020603", "primary": "#4dff88", "secondary": "#33cc66", "tertiary": "#ffb547",
                          "overBackground": "#7dffa4", "overSurface": "#7dffa4", "overSurfaceVariant": "#4fcf78",
                          "outline": "#1f7a3f", "outlineVariant": "#0f3a1e"},
                 "light": {"ground": "#eefaf1", "primary": "#0b7a35"}},
    "Ice": {"seed": "#9cc9f0", "scheme": "scheme-tonal-spot",
            "dark": {"ground": "#0d141c", "primary": "#d4ecff", "secondary": "#b9d3ea", "tertiary": "#c6e7f2",
                     "overBackground": "#eef6ff", "overSurface": "#eef6ff"},
            "light": {"ground": "#f2f8fd", "primary": "#2f6690"}},
    "Sage": {"seed": "#8a9a84", "scheme": "scheme-neutral",
             "dark": {"ground": "#141814", "primary": "#b7c9ae", "tertiary": "#c8c2a4"},
             "light": {"ground": "#f3f5f0"}},
    "Maple": {"seed": "#d2602f", "scheme": "scheme-content",
              "dark": {"ground": "#1b1110", "primary": "#ffb38a", "secondary": "#e59a8e", "tertiary": "#f07b5a",
                       "overTertiary": "#3d0d02",
                       "tertiaryContainer": "#6b1f33", "overTertiaryContainer": "#ffd9df"},
              "light": {"ground": "#fff4ee", "primary": "#a2410f", "tertiary": "#8c2440"}},
    "Vivid": {"seed": "#1ba1e2", "scheme": "scheme-vibrant",
              "dark": {"ground": "#141414", "primary": "#1ba1e2", "overPrimary": "#ffffff",
                       "primaryContainer": "#0a5c8a", "secondary": "#ff0097", "overSecondary": "#ffffff",
                       "tertiary": "#8cbf26", "overTertiary": "#101010", "surfaceTint": "#1ba1e2"},
              "light": {"ground": "#f4f4f4", "primary": "#1ba1e2", "overPrimary": "#ffffff",
                        "secondary": "#e3008c", "overSecondary": "#ffffff"}},
    "Neon": {"seed": "#ff2a6d", "scheme": "scheme-fidelity",
             "dark": {"ground": "#07050d", "primary": "#ff4f8b", "overPrimary": "#1a0010", "secondary": "#05d9e8",
                      "overSecondary": "#00262a", "tertiary": "#7df9ff", "overTertiary": "#00292c",
                      "surfaceTint": "#ff4f8b", "shadow": "#ff2a6d"},
             "light": {"ground": "#fbf3fa", "secondary": "#00838c"}},
    "Paper": {"seed": "#b07a4f", "scheme": "scheme-neutral",
              "dark": {"ground": "#1c1814"},
              "light": {"ground": "#f4ecd8", "surfaceContainerLowest": "#fbf6ea", "primary": "#8a4b2a",
                        "overBackground": "#2b2620", "overSurface": "#2b2620", "outline": "#8d8273",
                        "outlineVariant": "#d6cab3"}},
    "Hanko": {"seed": "#c8102e", "scheme": "scheme-monochrome",
              "dark": {"ground": "#121212", "primary": "#e5484d", "overPrimary": "#ffffff",
                       "primaryContainer": "#7a0f1c", "overPrimaryContainer": "#ffdadb", "surfaceTint": "#e5484d",
                       "inversePrimary": "#b3121f"},
              "light": {"ground": "#f5f3ef", "primary": "#b3121f", "overPrimary": "#ffffff",
                        "primaryContainer": "#ffdadb", "overPrimaryContainer": "#410006"}},
    # Kotoba: indigo-dyed night, unbleached cream type, a muted vermilion stamp
    "Indigo": {"seed": "#3b4f8f", "scheme": "scheme-neutral",
               "dark": {"ground": "#0f121c", "primary": "#b4c0e8", "secondary": "#c9c2b0", "tertiary": "#e09a7a",
                        "overBackground": "#e8e2d4", "overSurface": "#e8e2d4", "overSurfaceVariant": "#aaa79c",
                        "outline": "#5d6170", "outlineVariant": "#2a2f40", "surfaceTint": "#b4c0e8"},
               "light": {"ground": "#f3f1ea", "primary": "#2c3c78", "tertiary": "#a8482a",
                         "overBackground": "#1d2133", "overSurface": "#1d2133", "outlineVariant": "#d3cfc2"}},
    # Hanami: a spring afternoon, blush paper, sakura pink, young-leaf green, sky
    "Blossom": {"seed": "#d9668f", "scheme": "scheme-tonal-spot",
                "dark": {"ground": "#1b1517", "primary": "#ffb0c8", "secondary": "#b5d39a", "tertiary": "#a9cdee"},
                "light": {"ground": "#fbf3f2", "surfaceContainerLowest": "#fffafa", "primary": "#b23a64",
                          "overPrimary": "#ffffff", "primaryContainer": "#ffd9e3", "overPrimaryContainer": "#3f0019",
                          "secondary": "#4c7a3d", "overSecondary": "#ffffff", "tertiary": "#386b9a",
                          "overBackground": "#2c1f24", "overSurface": "#2c1f24", "outlineVariant": "#e6cfd5"}},
    # Emaki: gold leaf and vermilion on black lacquer
    "Kinpaku": {"seed": "#c9a24a", "scheme": "scheme-content",
                "dark": {"ground": "#120e0b", "primary": "#e3c27a", "overPrimary": "#2a1d00", "secondary": "#c8b79a",
                         "tertiary": "#e0715a", "overTertiary": "#3b0900", "overBackground": "#efe6d2",
                         "overSurface": "#efe6d2", "outline": "#7c6a4c", "outlineVariant": "#3a2f22",
                         "surfaceTint": "#e3c27a"},
                "light": {"ground": "#f6efe0", "primary": "#8a6416", "tertiary": "#a33a24",
                          "overBackground": "#2a2216", "overSurface": "#2a2216"}},
    # Device: a graphite instrument with an amber signal and a cyan LED
    "Signal": {"seed": "#ff7a1a", "scheme": "scheme-fidelity",
               "dark": {"ground": "#151617", "primary": "#ff8a2a", "overPrimary": "#2b1100",
                        "primaryContainer": "#6e3200", "overPrimaryContainer": "#ffdcc6", "secondary": "#4fd1d9",
                        "overSecondary": "#002f33", "tertiary": "#e8e4dc", "overTertiary": "#1f1d19",
                        "overBackground": "#ecebe7", "overSurface": "#ecebe7", "overSurfaceVariant": "#a3a29e",
                        "outline": "#5b5c5e", "outlineVariant": "#2e3032", "surfaceTint": "#ff8a2a"},
               "light": {"ground": "#e9e8e4", "primary": "#d4560a", "overPrimary": "#ffffff",
                         "secondary": "#00838c", "overSecondary": "#ffffff", "overBackground": "#1d1e20",
                         "overSurface": "#1d1e20"}},
}


def build(spec: dict, mode: str) -> dict:
    colors = material(spec["seed"], spec["scheme"], mode)
    over = dict(spec.get(mode, {}))
    ground = over.pop("ground", None)
    if ground:
        colors.update(ramp(ground, mode == "light"))
    colors.update(over)
    return dict(sorted(colors.items()))


def write(name: str) -> None:
    spec = PALETTES[name]
    d = OUT / name
    d.mkdir(parents=True, exist_ok=True)
    for mode in ("dark", "light"):
        colors = build(spec, mode)
        (d / f"{mode}.json").write_text(json.dumps(colors, indent=2) + "\n")
        lines = [colors["background"], *(colors[t] for t in TERMINAL), colors["overBackground"]]
        (d / mode).write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    for n in sys.argv[1:] or PALETTES:
        write(n)
        print(f"{n}: {OUT / n}")
