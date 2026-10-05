"""Per-image pixel diff of two shell_render.py output dirs (needs numpy + Pillow).

usage: render_diff.py <dir-a> <dir-b> [<heatmap-dir>]
Prints, per config: max channel diff, pixels differing by >2/>8/>24 levels
and the mean diff; optional heatmaps (diff x8) go to <heatmap-dir>.
"""
import sys, numpy as np
from pathlib import Path
from PIL import Image
a, b = Path(sys.argv[1]), Path(sys.argv[2])
rows = []
for f in sorted(a.glob("*.png")):
    g = b / f.name
    if not g.exists(): continue
    x = np.asarray(Image.open(f).convert("RGB"), dtype=np.int16)
    y = np.asarray(Image.open(g).convert("RGB"), dtype=np.int16)
    d = np.abs(x - y).max(axis=2)
    rows.append((f.stem, int(d.max()), int((d > 2).sum()), int((d > 8).sum()), int((d > 24).sum()), float(d.mean())))
    if len(sys.argv) > 3:
        out = Path(sys.argv[3]); out.mkdir(exist_ok=True)
        Image.fromarray(np.clip(d * 8, 0, 255).astype(np.uint8)).save(out / f.name)
rows.sort(key=lambda r: -r[3])
print(f"{'config':40} max  >2px  >8px  >24px  mean")
for r in rows: print(f"{r[0]:40} {r[1]:3} {r[2]:6} {r[3]:6} {r[4]:6} {r[5]:.3f}")
print("worst max", max(r[1] for r in rows), "total >8:", sum(r[3] for r in rows))
