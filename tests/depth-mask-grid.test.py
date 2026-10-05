"""scripts/depth_mask.py placement grid: still images and video mask stacks.

The grid is what ClockPlacement.js scores per clock style, so its format
(hex bytes, row-major, cols following the screen aspect) and the loop-wide
channels for videos (percentile cover, mean, per-pixel jitter) are checked
here. Needs numpy + Pillow (skipped otherwise).
"""
import importlib.util
import sys
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("depth-mask-grid: skipped (numpy/Pillow missing)")
    sys.exit(0)

spec = importlib.util.spec_from_file_location("depth_mask", Path(__file__).resolve().parents[1] / "scripts/depth_mask.py")
dm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dm)


def unhex(s, cols, rows):
    return np.frombuffer(bytes.fromhex(s), dtype=np.uint8).reshape(rows, cols) / 255.0


# Still: subject on the left half of a 16:9 image.
mask = np.zeros((360, 640), dtype=np.uint8)
mask[:, :320] = 255
frame = Image.fromarray(np.full((360, 640, 3), 230, dtype=np.uint8))
g = dm.analyse(Image.fromarray(mask, "L"), frame, 2560, 1440)["grid"]
assert (g["rows"], g["cols"]) == (dm.GRID_ROWS, 96), g.keys()
cover = unhex(g["cover"], g["cols"], g["rows"])
assert cover[:, :47].min() > 0.99 and cover[:, 49:].max() < 0.01
assert abs(unhex(g["lum"], g["cols"], g["rows"]).mean() - 230 / 255) < 0.02
assert "jitter" not in g

# Portrait screen: columns follow the aspect.
g = dm.analyse(Image.fromarray(mask, "L"), None, 1080, 1920)["grid"]
assert g["cols"] == round(1080 * dm.GRID_ROWS / 1920)
assert set(bytes.fromhex(g["lum"])) == {0}

# Video stack: the subject sweeps across in 20% of the frames, one corner flickers.
stack = np.zeros((20, 180, 320), dtype=np.uint8)
stack[:4, :, 200:] = 255
stack[::2, :40, :40] = 255
g = dm.analyse(stack, None, 2560, 1440)["grid"]
cols, rows = g["cols"], g["rows"]
p90 = unhex(g["cover"], cols, rows)
mean = unhex(g["mean"], cols, rows)
jit = unhex(g["jitter"], cols, rows)
assert g["frames"] == 20
assert p90[:, 70:].min() > 0.9, "the worst case over the loop counts"
assert abs(mean[:, 70:].mean() - 0.2) < 0.03
assert jit[:10, :10].mean() > 0.8, "flicker shows up as jitter"
assert jit[30:, 20:60].max() < 0.01
print("depth-mask-grid: ok")
