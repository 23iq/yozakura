#!/usr/bin/env python3
"""Foreground ("depth") mask generator for the desktop depth clock.

Runs inside the isolated venv created by ``depth_setup.sh``:

    <data dir>/venv-depth/bin/python depth_mask.py \
        <wallpaper> --cache-dir <cache dir>/depth --screen 2560x1440

For a wallpaper it writes, cached per path + mtime + size + model:

    <cache>/<key>.png   RGBA cutout at the source resolution: wallpaper pixels
                        with alpha = foreground (subject). RGB is zeroed where
                        alpha is 0 so the file compresses well. The shell draws
                        it with the same fill mode as the wallpaper itself, so
                        both line up pixel-perfectly without any shader.
    <key>.json          metadata + per screen-size placement grid (subject
                        coverage + luminance; scored per style in QML).

For videos/GIFs one representative frame is analysed; the cutout is still
written, but the shell only uses its placement data (a frozen subject over a
moving video looks wrong). Once ``depth_video.py`` has built a matte video
for the source (``<key>.matte.mp4`` + ``<key>.matte.npz``), placement is
computed from the whole loop instead and the result carries ``matte`` /
``matteInfo`` so the shell can play it.

The last stdout line is always one JSON object (also on errors), so the QML
side can parse it with a StdioCollector. Heavy imports (rembg/onnxruntime)
only happen on a cache miss.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import brand  # noqa: E402  (app identity: data dir, env prefix)

VERSION = 2      # bump to invalidate cached masks
LAYOUT_VERSION = 5  # bump to recompute placement only (5: style-agnostic grid)
DEFAULT_MODEL = "isnet-anime"
IMAGE_EXT = {"jpg", "jpeg", "png", "webp", "tif", "tiff", "bmp"}
VIDEO_EXT = {"mp4", "webm", "mov", "avi", "mkv", "gif"}
# Inference resolution cap: the models run at ~1024px internally, so feeding
# them 8K images only costs time. The mask is upscaled back afterwards.
INFER_MAX = 2048

# Placement is scored per clock style in QML (ClockPlacement.js) from a
# coarse grid of the wallpaper as shown on that screen: subject coverage +
# backdrop luminance per cell (+ loop-wide worst case and instability for
# video mattes). GRID_ROWS cells tall, columns follow the screen aspect.
GRID_ROWS = 54
# Videos: per-cell coverage percentile over the loop used as "cover", so a
# style counts as depth-capable only if its digits stay readable for (nearly)
# the whole loop, not just on average.
LOOP_PERCENTILE = 90
FRAME_H = 480               # height of the small analysis frame kept in cache
CACHE_KEEP = 48             # wallpapers kept in the cache (oldest pruned)

def out(obj, code=0):
    print(json.dumps(obj), flush=True)
    sys.exit(code)


def kind_of(path):
    ext = path.rsplit(".", 1)[-1].lower() if "." in path else ""
    if ext in IMAGE_EXT:
        return "image"
    if ext in VIDEO_EXT:
        return "video"
    return None


def cache_key(path, model):
    st = os.stat(path)
    raw = f"{os.path.realpath(path)}|{st.st_mtime_ns}|{st.st_size}|{model}|v{VERSION}"
    return hashlib.sha1(raw.encode()).hexdigest()[:20]


def video_frame(path, tmpdir):
    """Grab a frame ~10% into the video (skips fade-ins), else the first."""
    dst = os.path.join(tmpdir, "frame.png")
    ts = 0.0
    try:
        dur = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", path],
            capture_output=True, text=True, timeout=20).stdout.strip()
        ts = min(float(dur) * 0.1, 3.0)
    except (ValueError, OSError, subprocess.SubprocessError):
        ts = 0.0
    for seek in (ts, 0.0):
        try:
            subprocess.run(
                ["ffmpeg", "-v", "error", "-y", "-ss", f"{seek:.2f}", "-i", path,
                 "-frames:v", "1", dst],
                capture_output=True, timeout=60, check=True)
            if os.path.exists(dst):
                return dst
        except (OSError, subprocess.SubprocessError):
            continue
    return None


def crop_to_screen(mask, sw, sh):
    """Replicate Qt's PreserveAspectCrop (scale to cover, centre crop)."""
    from PIL import Image
    w, h = mask.size
    scale = max(sw / w, sh / h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    m = mask.resize((nw, nh), Image.BILINEAR)
    left, top = (nw - sw) // 2, (nh - sh) // 2
    return m.crop((left, top, left + sw, top + sh))


def screen_masks(mask, w, h):
    """Yield the mask(s) cropped to a w x h screen, as float arrays in 0..1.

    ``mask`` is either one PIL image (a still / single frame) or a uint8
    numpy stack ``(T, H, W)`` sampled over a whole video."""
    import numpy as np
    from PIL import Image
    if isinstance(mask, np.ndarray) and mask.ndim == 3:
        for m in mask:
            yield np.asarray(crop_to_screen(Image.fromarray(m, "L"), w, h), dtype=np.float32) / 255.0
    else:
        yield np.asarray(crop_to_screen(mask, w, h), dtype=np.float32) / 255.0


def analyse(mask, frame, sw, sh):
    """Downsample what a sw x sh screen shows into a coarse grid.

    Returns {"grid": {"cols", "rows", "cover", "lum"[, "mean", "jitter"]}}:
    one byte per cell, row-major, hex-encoded (compact, trivial to read in
    QML). ``cover`` is the subject alpha; with a video mask stack it is the
    LOOP_PERCENTILE over all frames (worst case), ``mean`` the average and
    ``jitter`` the mean frame-to-frame change (segmentation instability)."""
    import numpy as np
    from PIL import Image
    rows = GRID_ROWS
    cols = max(1, round(sw * rows / sh))
    # Crop at a moderate size first so the box filter averages real pixels.
    h = rows * 4
    w = max(1, round(sw * h / sh))

    def to_grid(a):
        img = Image.fromarray(np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8), "L")
        return np.asarray(img.resize((cols, rows), Image.BOX), dtype=np.float32) / 255.0

    def hexed(a):
        return np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8).tobytes().hex()

    frames = []
    jitter = None
    prev = None
    for a in screen_masks(mask, w, h):
        frames.append(to_grid(a))
        if prev is not None:
            # Per-pixel change, averaged per cell afterwards: edge flicker
            # must not cancel out inside a cell.
            d = np.abs(a - prev)
            jitter = d if jitter is None else jitter + d
        prev = a
    if not frames:
        frames = [np.zeros((rows, cols), dtype=np.float32)]
    stack = np.stack(frames)
    grid = {"cols": cols, "rows": rows}
    if len(frames) > 1:
        grid["cover"] = hexed(np.percentile(stack, LOOP_PERCENTILE, axis=0))
        grid["mean"] = hexed(stack.mean(axis=0))
        grid["jitter"] = hexed(to_grid(jitter / (len(frames) - 1)))
        grid["frames"] = len(frames)
    else:
        grid["cover"] = hexed(stack[0])
    if frame is not None:
        lum = crop_to_screen(frame.convert("L"), w, h).resize((cols, rows), Image.BOX)
        grid["lum"] = np.asarray(lum, dtype=np.uint8).tobytes().hex()
    else:
        grid["lum"] = "00" * (cols * rows)
    return {"grid": grid}


def refine(mask):
    """Gently sharpen low-confidence haze so the clock is not half-veiled."""
    import numpy as np
    from PIL import Image
    a = np.asarray(mask, dtype=np.float32) / 255.0
    lo, hi = 0.08, 0.80
    t = np.clip((a - lo) / (hi - lo), 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)
    return Image.fromarray((t * 255.0 + 0.5).astype(np.uint8), "L")


KEY_JSON = re.compile(r"^[0-9a-f]{20}\.json$")


def prune(cache_dir, keep):
    try:
        metas = sorted(
            (e for e in os.scandir(cache_dir) if KEY_JSON.match(e.name)),
            key=lambda e: e.stat().st_mtime, reverse=True)
    except OSError:
        return
    for e in metas[keep:]:
        stem = e.path[:-len(".json")]
        for suffix in (".json", ".png", ".frame.jpg", ".matte.mp4", ".matte.npz"):
            try:
                os.remove(stem + suffix)
            except OSError:
                pass
        shutil.rmtree(stem + ".matte.part", ignore_errors=True)


def load_matte(cache_dir, key):
    """(info, masks) of a finished matte video, or None. ``masks`` is a small
    uint8 (T, H, W) stack sampled over the loop, for placement analysis."""
    mp4 = os.path.join(cache_dir, key + ".matte.mp4")
    npz = os.path.join(cache_dir, key + ".matte.npz")
    if not (os.path.exists(mp4) and os.path.exists(npz)):
        return None
    try:
        import numpy as np
        with np.load(npz) as data:
            info = json.loads(str(data["info"]))
            masks = data["masks"]
    except (OSError, ValueError, KeyError):
        return None
    if info.get("version") is None:
        return None
    info["file"] = mp4
    return info, masks


def preload_gpu_libs():
    """onnxruntime-gpu installed with the pip CUDA/cuDNN wheels needs them
    preloaded; harmless (and skipped) on the CPU build."""
    try:
        import onnxruntime as ort
        if ort.get_device() == "GPU" and hasattr(ort, "preload_dlls"):
            ort.preload_dlls()
    except Exception:  # noqa: BLE001 - CPU fallback still works
        pass


def generate(src_img_path, model, models_dir):
    os.environ.setdefault("U2NET_HOME", models_dir)
    # Be a polite background job.
    os.environ.setdefault("OMP_NUM_THREADS", str(max(1, (os.cpu_count() or 4) // 2)))
    from PIL import Image
    preload_gpu_libs()
    from rembg import new_session, remove

    img = Image.open(src_img_path)
    img.seek(0)
    img = img.convert("RGB")
    small = img.copy()
    small.thumbnail((INFER_MAX, INFER_MAX), Image.LANCZOS)
    session = new_session(model)
    mask = remove(small, session=session, only_mask=True, post_process_mask=False)
    if mask.size != img.size:
        mask = mask.resize(img.size, Image.BICUBIC)
    mask = refine(mask)
    return img, mask


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--cache-dir", required=True)
    ap.add_argument("--screen", action="append", default=[],
                    help="WxH of a screen showing this wallpaper (repeatable)")
    ap.add_argument("--model", default=brand.brand_env("DEPTH_MODEL", DEFAULT_MODEL))
    ap.add_argument("--models-dir",
                    default=os.path.join(brand.DATA_DIR, "depth-models"))
    args = ap.parse_args()

    src = os.path.expanduser(args.source)
    base = {"source": args.source, "ok": False}
    if not os.path.isfile(src):
        out({**base, "error": "missing source"}, 1)
    kind = kind_of(src)
    if kind is None:
        out({**base, "error": "unsupported type"}, 1)

    os.makedirs(args.cache_dir, exist_ok=True)
    key = cache_key(src, args.model)
    png = os.path.join(args.cache_dir, key + ".png")
    meta_path = os.path.join(args.cache_dir, key + ".json")
    frame_path = os.path.join(args.cache_dir, key + ".frame.jpg")

    meta = None
    if os.path.exists(png) and os.path.exists(meta_path):
        try:
            with open(meta_path) as fh:
                meta = json.load(fh)
        except (OSError, ValueError):
            meta = None

    if meta is not None and meta.get("layoutVersion") != LAYOUT_VERSION:
        meta["layouts"] = {}
        meta["layoutVersion"] = LAYOUT_VERSION

    # A finished matte video replaces the single-frame placement.
    matte = load_matte(args.cache_dir, key) if kind == "video" else None
    layout_source = "video" if matte else "frame"
    if meta is not None and meta.get("layoutSource", "frame") != layout_source:
        meta["layouts"] = {}

    screens = []
    for s in args.screen:
        try:
            w, h = (int(v) for v in s.lower().split("x"))
            if w > 0 and h > 0:
                screens.append((w, h))
        except ValueError:
            pass

    missing = [s for s in screens
               if meta is None or f"{s[0]}x{s[1]}" not in meta.get("layouts", {})]

    if meta is None or missing:
        from PIL import Image
        if meta is None:
            with tempfile.TemporaryDirectory() as tmp:
                frame = src if kind == "image" else video_frame(src, tmp)
                if not frame:
                    out({**base, "error": "could not extract a frame"}, 1)
                try:
                    img, mask = generate(frame, args.model, args.models_dir)
                except Exception as exc:  # noqa: BLE001 - report, never crash the shell
                    out({**base, "error": f"inference failed: {exc}"}, 1)
            import numpy as np
            # Straight (non-premultiplied) alpha: keep the true colours where
            # the subject is, zero them elsewhere for compression.
            rgba = np.dstack([np.asarray(img), np.asarray(mask)])
            rgba[rgba[..., 3] == 0, :3] = 0
            cut = Image.fromarray(rgba, "RGBA")
            tmp_png = png + ".tmp.png"
            cut.save(tmp_png, compress_level=3)
            os.replace(tmp_png, png)
            # Small copy of the full frame for later placement analysis
            # (other screen sizes) without re-decoding the source.
            frame = img.copy()
            frame.thumbnail((FRAME_H * 4, FRAME_H), Image.BILINEAR)
            frame.save(frame_path, quality=85)
            meta = {
                "version": VERSION,
                "layoutVersion": LAYOUT_VERSION,
                "model": args.model,
                "kind": kind,
                "source": src,
                "width": img.width,
                "height": img.height,
                "layouts": {},
            }
        else:
            mask = Image.open(png).getchannel("A")
            frame = Image.open(frame_path) if os.path.exists(frame_path) else None
        for w, h in missing:
            meta["layouts"][f"{w}x{h}"] = analyse(matte[1] if matte else mask, frame, w, h)
        meta["layoutSource"] = layout_source
        tmp_meta = meta_path + ".tmp"
        with open(tmp_meta, "w") as fh:
            json.dump(meta, fh)
        os.replace(tmp_meta, meta_path)
        prune(args.cache_dir, CACHE_KEEP)
    else:
        try:
            os.utime(meta_path)  # keep recently used entries out of pruning
        except OSError:
            pass

    res = {**base, "ok": True, "key": key, "cutout": png, **meta}
    if matte:
        res["matte"] = matte[0]["file"]
        res["matteInfo"] = matte[0]
    out(res)


if __name__ == "__main__":
    main()
