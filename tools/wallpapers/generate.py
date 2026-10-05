#!/usr/bin/env python3
"""Render the bundled example wallpapers (assets/wallpapers_example).

Each wallpaper is a layered night landscape — sky gradient, moon glow,
rolling hills, drifting petals — with the Yozakura mark in the centre.
Everything is vector and seeded, so the set is reproducible:

    python3 tools/wallpapers/generate.py            # 3840x2160 PNGs
    python3 tools/wallpapers/generate.py --svg-only # keep the SVGs only

Rasterising needs rsvg-convert (librsvg) or resvg on PATH.
"""

import argparse
import math
import random
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets" / "wallpapers_example"
W, H = 3840, 2160

# The five-petal mark (assets/yozakura/yozakura-icon.svg), 24x24 viewBox.
LOGO = (
    "M 12.00 9.30 C 9.10 8.40 6.80 5.60 7.70 2.60 C 8.20 0.90 9.90 0.10 11.00 0.40 L 12.00 1.90 L 13.00 0.40 "
    "C 14.10 0.10 15.80 0.90 16.30 2.60 C 17.20 5.60 14.90 8.40 12.00 9.30 Z M 14.57 11.17 C 14.53 8.13 16.48 5.08 "
    "19.61 5.01 C 21.38 4.96 22.67 6.33 22.72 7.46 L 21.61 8.88 L 23.34 9.37 C 23.97 10.32 23.73 12.18 22.27 13.18 "
    "C 19.69 14.97 16.32 13.65 14.57 11.17 Z M 13.59 14.18 C 16.46 13.21 19.97 14.12 21.00 17.08 C 21.60 18.75 "
    "20.69 20.39 19.63 20.80 L 17.94 20.17 L 18.01 21.97 C 17.30 22.86 15.45 23.21 14.05 22.13 C 11.55 20.23 "
    "11.77 16.62 13.59 14.18 Z M 10.41 14.18 C 12.23 16.62 12.45 20.23 9.95 22.13 C 8.55 23.21 6.70 22.86 5.99 "
    "21.97 L 6.06 20.17 L 4.37 20.80 C 3.31 20.39 2.40 18.75 3.00 17.08 C 4.03 14.12 7.54 13.21 10.41 14.18 Z "
    "M 9.43 11.17 C 7.68 13.65 4.31 14.97 1.73 13.18 C 0.27 12.18 0.03 10.32 0.66 9.37 L 2.39 8.88 L 1.28 7.46 "
    "C 1.33 6.33 2.62 4.96 4.39 5.01 C 7.52 5.08 9.47 8.13 9.43 11.17 Z"
)
# One petal of the mark, recentred on its own middle (≈ 12, 4.85).
PETAL = (
    "M 0 4.45 C -2.9 3.55 -5.2 0.75 -4.3 -2.25 C -3.8 -3.95 -2.1 -4.75 -1 -4.45 L 0 -2.95 L 1 -4.45 "
    "C 2.1 -4.75 3.8 -3.95 4.3 -2.25 C 5.2 0.75 2.9 3.55 0 4.45 Z"
)

# name, sky top, sky bottom, hills (far → near), moon, petals, logo, stars
PALETTES = [
    ("yozakura", "#0b0a1a", "#2a1430", ["#3a1d3f", "#2a1430", "#1b0e22", "#100816"], "#ffe9f0", "#f4a7c0", "#f7c3d4", True),
    ("koyo", "#140806", "#3a120a", ["#5a1d0e", "#43150b", "#2c0d07", "#1a0704"], "#ffd8b0", "#ff7a3d", "#ffb27a", True),
    ("matcha", "#06110b", "#163322", ["#1f4a30", "#173a25", "#10291a", "#09190f"], "#e8f6dc", "#a8d58a", "#c9e8b4", True),
    ("fuji", "#050b18", "#13284a", ["#1b3a66", "#152d52", "#0e1f3a", "#081324"], "#e3f0ff", "#8fb8ff", "#bcd6ff", True),
    ("neon", "#0a0418", "#2a0b45", ["#3d1166", "#2e0c4f", "#1f0836", "#12041f"], "#d9fbff", "#4de8ff", "#ff6ad5", True),
    ("ume", "#12040c", "#3d0a24", ["#5c1236", "#470d2a", "#300820", "#1c0412"], "#ffe0ec", "#ff5c8a", "#ff9bb8", True),
    ("sumi", "#0c0c0d", "#1d1d20", ["#2b2b2f", "#222225", "#18181a", "#0f0f10"], "#f2f2f2", "#9a9aa0", "#d8d8dc", True),
    ("kuro", "#000000", "#08080a", ["#121214", "#0d0d0f", "#08080a", "#040405"], "#cfcfd4", "#5a5a60", "#a0a0a8", True),
    ("hanami", "#fde8ef", "#f7c6d6", ["#eea5bf", "#e48aaa", "#d16f93", "#b9577c"], "#fffaf3", "#ffffff", "#7a2a48", False),
    ("washi", "#f3ead8", "#e6d6b8", ["#d4bd94", "#c2a579", "#a98a60", "#8a6d48"], "#fffdf6", "#c0392b", "#3b2a1a", False),
]


def hill_path(rng: random.Random, base_y: float, amp: float, waves: int) -> str:
    """A smooth closed hill silhouette across the full width."""
    n = waves * 2 + 1
    pts = []
    phase = rng.uniform(0, math.tau)
    for i in range(n + 1):
        x = W * i / n
        y = base_y + amp * math.sin(phase + i * math.pi / 1.7) + rng.uniform(-amp, amp) * 0.35
        pts.append((x, y))
    d = [f"M {-50} {H + 50} L {-50} {pts[0][1]:.1f}"]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:], strict=False):
        mx = (x0 + x1) / 2
        d.append(f"C {mx:.1f} {y0:.1f} {mx:.1f} {y1:.1f} {x1:.1f} {y1:.1f}")
    d.append(f"L {W + 50} {pts[-1][1]:.1f} L {W + 50} {H + 50} Z")
    return " ".join(d)


def render_svg(idx: int, pal) -> str:
    name, sky0, sky1, hills, moon, petal, logo, dark = pal
    rng = random.Random(f"yozakura-{name}")
    moon_x = rng.uniform(0.62, 0.82) * W
    moon_y = rng.uniform(0.16, 0.26) * H
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">',
        "<defs>",
        f'<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{sky0}"/><stop offset="1" stop-color="{sky1}"/></linearGradient>',
        f'<radialGradient id="glow"><stop offset="0" stop-color="{moon}" stop-opacity="0.45"/><stop offset="0.35" stop-color="{moon}" stop-opacity="0.12"/><stop offset="1" stop-color="{moon}" stop-opacity="0"/></radialGradient>',
        f'<radialGradient id="halo"><stop offset="0" stop-color="{logo}" stop-opacity="0.22"/><stop offset="1" stop-color="{logo}" stop-opacity="0"/></radialGradient>',
        "</defs>",
        f'<rect width="{W}" height="{H}" fill="url(#sky)"/>',
    ]
    if dark:
        for _ in range(170):
            x, y = rng.uniform(0, W), rng.uniform(0, H * 0.55)
            r = rng.choice((1.6, 2.2, 2.2, 3.0, 4.0))
            parts.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="{moon}" opacity="{rng.uniform(0.25, 0.8):.2f}"/>')
    parts.append(f'<circle cx="{moon_x:.0f}" cy="{moon_y:.0f}" r="{H * 0.42:.0f}" fill="url(#glow)"/>')
    parts.append(f'<circle cx="{moon_x:.0f}" cy="{moon_y:.0f}" r="{H * 0.075:.0f}" fill="{moon}"/>')

    # Hills, far to near; petals interleave so some drift behind the ridges.
    layers = [(0.60, 90, 3), (0.70, 110, 4), (0.81, 120, 3), (0.92, 90, 5)]

    def petals(count, smin, smax, omin, omax):
        for _ in range(count):
            s = rng.uniform(smin, smax)
            x, y = rng.uniform(-40, W + 40), rng.uniform(-40, H + 40)
            a = rng.uniform(0, 360)
            parts.append(
                f'<path d="{PETAL}" fill="{petal}" opacity="{rng.uniform(omin, omax):.2f}" '
                f'transform="translate({x:.0f} {y:.0f}) rotate({a:.0f}) scale({s:.2f} {s * rng.uniform(0.55, 1):.2f})"/>'
            )

    petals(60, 2.0, 3.6, 0.25, 0.5)
    for i, ((by, amp, waves), color) in enumerate(zip(layers, hills, strict=True)):
        parts.append(f'<path d="{hill_path(rng, by * H, amp, waves)}" fill="{color}"/>')
        if i == 1:
            petals(25, 3.6, 5.5, 0.45, 0.75)
    petals(10, 6.5, 9.5, 0.65, 0.9)

    # Centre mark with a soft halo, sized like the old example set.
    size = H * 0.20
    cx, cy = W / 2, H * 0.47
    parts.append(f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{size * 1.4:.0f}" fill="url(#halo)"/>')
    k = size / 24
    parts.append(
        f'<path d="{LOGO}" fill="{logo}" fill-rule="evenodd" '
        f'transform="translate({cx - size / 2:.1f} {cy - size / 2:.1f}) scale({k:.3f})"/>'
    )
    parts.append("</svg>")
    return "\n".join(parts)


def rasterise(svg: Path, png: Path) -> None:
    if shutil.which("rsvg-convert"):
        cmd = ["rsvg-convert", "-w", str(W), "-h", str(H), "-o", str(png), str(svg)]
    elif shutil.which("resvg"):
        cmd = ["resvg", "-w", str(W), "-h", str(H), str(svg), str(png)]
    else:
        sys.exit("need rsvg-convert or resvg to rasterise")
    subprocess.run(cmd, check=True)
    if shutil.which("oxipng"):
        subprocess.run(["oxipng", "-q", "-o", "2", "--strip", "safe", str(png)], check=True)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--svg-only", action="store_true", help="write SVGs next to the PNGs instead of rasterising")
    ap.add_argument("--out", type=Path, default=OUT)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for i, pal in enumerate(PALETTES, 1):
            svg = (args.out if args.svg_only else Path(tmp)) / f"wallpaper-{i:02d}.svg"
            svg.write_text(render_svg(i, pal))
            if not args.svg_only:
                rasterise(svg, args.out / f"wallpaper-{i:02d}.png")
            print(f"wallpaper-{i:02d}  {pal[0]}")


if __name__ == "__main__":
    main()
