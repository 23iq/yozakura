#!/usr/bin/env python3
"""Stacked-alpha "matte video" generator for the depth clock on video wallpapers.

Runs inside the venv created by ``depth_setup.sh``, as a niced background job:

    <data dir>/venv-depth/bin/python depth_video.py <video> \
        --cache-dir <cache dir>/depth

Every frame of the source is segmented once (isnet-anime) and the result is
encoded into ONE video that holds the colour frame on top and its foreground
mask (as luma) at the bottom:

    +-----------+   W x Hp   colour (source frame, padded to 16 rows)
    |  colour   |
    +-----------+
    |   mask    |   W x Hp   alpha: white = subject, black = backdrop
    +-----------+

Same frame count and frame rate as the source, so it loops identically, and
since colour and alpha come out of the same decoder they can never drift
apart. The shell plays it instead of the source and draws the top half as the
wallpaper and the top half masked by the bottom half above the clock.

Cache (shared key with depth_mask.py: path + mtime + size + model):

    <key>.matte.mp4    the stacked video (H.264, yuv420p, faststart)
    <key>.matte.npz    {info: JSON, masks: small uint8 (T, h, w) stack} used by
                       depth_mask.py to place the clock for the whole loop
    <key>.matte.part/  per-frame raw masks while segmenting; makes a cancelled
                       job resumable (kill it any time, rerun to continue)

stdout protocol: zero or more progress lines
    {"progress": 0.42, "stage": "segment"|"encode", "frame": n, "frames": N}
then exactly one final JSON object (also on errors). ``permanent: true`` on an
error means retrying will not help (too long, unsupported, ...).
"""

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import depth_mask as dm  # noqa: E402  (shared cache key / helpers)
from depth_mask import brand  # noqa: E402  (app identity, see scripts/lib)

MATTE_VERSION = 1           # bump to rebuild every matte
MAX_SECONDS = 60.0          # longer videos keep the clock in front
MAX_FRAMES = 3600
# Output pixel budget per half. 2560x1440 -> 2560x2880 stays within H.264
# level 5.1 and every hardware decoder; bigger sources are scaled down.
MAX_HALF_PIXELS = 2560 * 1440
MAX_SIDE = 4096
MASK_W = 1280               # stored raw mask width (model runs at 1024x1024)
MODEL_SIZE = 1024
DIS_MODELS = {"isnet-anime", "isnet-general-use"}
MEAN = (0.485, 0.456, 0.406)
MEDIAN_RADIUS = 2           # temporal median over 2r+1 frames (loop-wrapped)
FEATHER = 1.0               # gaussian blur radius on the mask, in mask pixels
STACK_W = 320               # placement stack width
STACK_FRAMES = 240          # max frames kept for placement
CRF = 18
GOP_SECONDS = 2
MATTES_KEEP = 8             # finished mattes kept (oldest pruned)
PART_MAX_AGE = 7 * 86400    # abandoned partial jobs are dropped after this

_children = []


def emit(obj):
    print(json.dumps(obj), flush=True)


def fail(base, error, permanent=False, code=1):
    _kill_children()
    emit({**base, "ok": False, "error": error, "permanent": permanent})
    sys.exit(code)


def _kill_children():
    for p in _children:
        try:
            p.kill()
        except OSError:
            pass


def _on_signal(signum, _frame):
    _kill_children()
    # Partial masks stay on disk: the next run resumes from them.
    sys.exit(128 + signum)


def probe(path):
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height,r_frame_rate,avg_frame_rate,nb_frames",
         "-show_entries", "format=duration", "-of", "json", path],
        capture_output=True, text=True, timeout=30)
    data = json.loads(r.stdout or "{}")
    st = (data.get("streams") or [{}])[0]
    fmt = data.get("format") or {}

    def rate(s):
        try:
            n, d = (int(v) for v in str(s).split("/"))
            return (n, d) if n > 0 and d > 0 else None
        except ValueError:
            return None

    fr = rate(st.get("r_frame_rate")) or rate(st.get("avg_frame_rate")) or (30, 1)
    duration = float(fmt.get("duration") or 0.0)
    try:
        frames = int(st.get("nb_frames") or 0)
    except ValueError:
        frames = 0
    if frames <= 0:
        frames = int(round(duration * fr[0] / fr[1]))
    return {
        "width": int(st.get("width") or 0),
        "height": int(st.get("height") or 0),
        "rate": fr,
        "fps": fr[0] / fr[1],
        "duration": duration,
        "frames": frames,
    }


def output_size(w, h):
    """Even output size within the pixel budget; height padded to 16 rows so
    no macroblock straddles colour and mask."""
    scale = min(1.0, (MAX_HALF_PIXELS / float(w * h)) ** 0.5, MAX_SIDE / float(w), (MAX_SIDE / 2) / float(h))
    ow = max(2, int(w * scale) // 2 * 2)
    oh = max(2, int(h * scale) // 2 * 2)
    ph = (oh + 15) // 16 * 16
    return ow, oh, ph


def model_path(model, models_dir):
    for root, _dirs, files in os.walk(models_dir):
        if f"{model}.onnx" in files:
            return os.path.join(root, f"{model}.onnx")
    # Not downloaded yet: let rembg fetch it.
    os.environ.setdefault("U2NET_HOME", models_dir)
    from rembg import new_session
    new_session(model)
    for root, _dirs, files in os.walk(models_dir):
        if f"{model}.onnx" in files:
            return os.path.join(root, f"{model}.onnx")
    raise RuntimeError(f"model {model} not found")


def make_session(path, provider):
    """CUDA when onnxruntime-gpu works (checked with a real run, since the
    provider is listed even without cuDNN), else CPU with half the cores."""
    import numpy as np
    import onnxruntime as ort
    dm.preload_gpu_libs()
    tried = []
    if provider in ("auto", "cuda") and "CUDAExecutionProvider" in ort.get_available_providers():
        try:
            s = ort.InferenceSession(path, providers=["CUDAExecutionProvider"])
            s.run(None, {s.get_inputs()[0].name: np.zeros((1, 3, MODEL_SIZE, MODEL_SIZE), np.float32)})
            return s, "cuda"
        except Exception as exc:  # noqa: BLE001
            tried.append(f"cuda: {exc}".splitlines()[0][:200])
            if provider == "cuda":
                raise
    so = ort.SessionOptions()
    so.intra_op_num_threads = max(1, (os.cpu_count() or 4) // 2)
    so.inter_op_num_threads = 1
    return ort.InferenceSession(path, so, providers=["CPUExecutionProvider"]), "cpu"


def decode(src, vf, extra_in=()):
    cmd = ["ffmpeg", "-v", "error", "-nostdin", *extra_in, "-i", src, "-an", "-sn",
           "-fps_mode", "passthrough", "-vf", vf, "-f", "rawvideo", "-pix_fmt", "rgb24", "pipe:1"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
    _children.append(p)
    return p


def read_exact(stream, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = stream.read(n - len(buf))
        if not chunk:
            break
        buf += chunk
    return bytes(buf)


def segment(src, part, info, session, mask_size, progress):
    """Run the model on every frame, writing raw masks to part/NNNNNN.png.
    Resumes after the last mask already on disk."""
    import numpy as np
    from PIL import Image
    mw, mh = mask_size
    done = 0
    while os.path.exists(os.path.join(part, f"{done:06d}.png")):
        done += 1
    total = info["frames"]
    if done >= total:
        return total
    vf = f"select=gte(n\\,{done}),scale={MODEL_SIZE}:{MODEL_SIZE}:flags=bicubic" if done else \
        f"scale={MODEL_SIZE}:{MODEL_SIZE}:flags=bicubic"
    p = decode(src, vf)
    name = session.get_inputs()[0].name
    mean = np.array(MEAN, dtype=np.float32).reshape(3, 1, 1)
    fsize = MODEL_SIZE * MODEL_SIZE * 3
    idx = done
    last = 0.0
    while True:
        raw = read_exact(p.stdout, fsize)
        if len(raw) < fsize:
            break
        x = np.frombuffer(raw, np.uint8).reshape(MODEL_SIZE, MODEL_SIZE, 3)
        x = x.transpose(2, 0, 1).astype(np.float32) / 255.0 - mean
        # Raw sigmoid output: no per-frame min/max stretch (rembg does that
        # for stills), which would make the mask pump from frame to frame.
        pred = session.run(None, {name: x[None]})[0][0, 0]
        m = Image.fromarray(np.clip(pred * 255.0 + 0.5, 0, 255).astype(np.uint8), "L")
        m = m.resize((mw, mh), Image.BILINEAR)
        tmp = os.path.join(part, f"{idx:06d}.tmp.png")
        m.save(tmp, compress_level=1)
        os.replace(tmp, os.path.join(part, f"{idx:06d}.png"))
        idx += 1
        now = time.monotonic()
        if now - last > 0.5:
            last = now
            progress("segment", idx, max(total, idx))
    p.wait()
    return idx


def smooth_masks(part, count, mask_size):
    """Yield the final mask per frame: temporal median over neighbouring
    frames (wrapping around, the wallpaper loops), then the same haze clean-up
    as stills plus a slight feather."""
    import numpy as np
    from PIL import Image, ImageFilter
    r = min(MEDIAN_RADIUS, (count - 1) // 2)
    cache = {}

    def raw(i):
        i %= count
        if i not in cache:
            with Image.open(os.path.join(part, f"{i:06d}.png")) as im:
                cache[i] = np.asarray(im.convert("L"))
        return cache[i]

    for i in range(count):
        for k in [k for k in cache if (k - (i - r)) % count > 2 * r]:
            del cache[k]
        win = np.stack([raw(i + d) for d in range(-r, r + 1)])
        med = np.median(win, axis=0).astype(np.uint8) if r > 0 else win[0]
        m = dm.refine(Image.fromarray(med, "L"))
        if FEATHER > 0:
            m = m.filter(ImageFilter.GaussianBlur(FEATHER))
        yield m


def encode(src, dst, info, size, mask_size, masks, count, progress):
    """Colour on top, mask below; frame N of the output = frame N of both."""
    ow, oh, ph = size
    mw, mh = mask_size
    num, den = info["rate"]
    fc = (
        f"[0:v]setpts=N*{den}/{num}/TB,scale={ow}:{oh}:flags=lanczos,format=yuv420p,"
        f"pad={ow}:{ph}:0:0:black[c];"
        f"[1:v]setpts=N*{den}/{num}/TB,scale={ow}:{oh}:flags=bicubic,format=gray,"
        f"pad={ow}:{ph}:0:0:black,format=yuv420p[m];"
        f"[c][m]vstack=inputs=2:shortest=1[v]"
    )
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", src,
           "-f", "rawvideo", "-pix_fmt", "gray", "-s", f"{mw}x{mh}", "-framerate", f"{num}/{den}", "-i", "pipe:0",
           "-filter_complex", fc, "-map", "[v]", "-an", "-frames:v", str(count),
           "-c:v", "libx264", "-preset", "medium", "-crf", str(CRF), "-pix_fmt", "yuv420p",
           "-color_range", "tv", "-g", str(max(1, round(info["fps"] * GOP_SECONDS))),
           "-r", f"{num}/{den}", "-movflags", "+faststart", "-f", "mp4", dst]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    _children.append(p)
    import numpy as np
    from PIL import Image
    step = max(1, -(-count // STACK_FRAMES))
    sw = min(STACK_W, mw)
    sh = max(1, round(mh * sw / mw))
    stack = []
    last = 0.0
    try:
        for i, m in enumerate(masks):
            p.stdin.write(m.tobytes())
            if i % step == 0:
                stack.append(np.asarray(m.resize((sw, sh), Image.BILINEAR)))
            now = time.monotonic()
            if now - last > 0.5:
                last = now
                progress("encode", i + 1, count)
        p.stdin.close()
    except BrokenPipeError:
        pass
    err = p.stderr.read().decode(errors="replace")
    if p.wait() != 0:
        raise RuntimeError(f"ffmpeg encode failed: {err.strip()[-300:]}")
    return np.stack(stack) if stack else np.zeros((1, sh, sw), np.uint8)


def prune_mattes(cache_dir, keep):
    now = time.time()
    try:
        entries = list(os.scandir(cache_dir))
    except OSError:
        return
    mattes = sorted((e for e in entries if e.name.endswith(".matte.npz")),
                    key=lambda e: e.stat().st_mtime, reverse=True)
    for e in mattes[keep:]:
        stem = e.path[:-len(".matte.npz")]
        for suffix in (".matte.npz", ".matte.mp4"):
            try:
                os.remove(stem + suffix)
            except OSError:
                pass
    for e in entries:
        if e.name.endswith(".matte.part") and e.is_dir():
            try:
                if now - e.stat().st_mtime > PART_MAX_AGE:
                    shutil.rmtree(e.path, ignore_errors=True)
            except OSError:
                pass
        elif e.name.endswith(".matte.tmp.mp4"):
            try:
                if now - e.stat().st_mtime > 3600:
                    os.remove(e.path)
            except OSError:
                pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--cache-dir", required=True)
    ap.add_argument("--model", default=brand.brand_env("DEPTH_MODEL", dm.DEFAULT_MODEL))
    ap.add_argument("--models-dir",
                    default=os.path.join(brand.DATA_DIR, "depth-models"))
    ap.add_argument("--provider", choices=("auto", "cpu", "cuda"),
                    default=brand.brand_env("DEPTH_PROVIDER", "auto"))
    ap.add_argument("--max-seconds", type=float, default=MAX_SECONDS)
    ap.add_argument("--check", action="store_true", help="only report whether a matte exists")
    args = ap.parse_args()

    signal.signal(signal.SIGTERM, _on_signal)
    signal.signal(signal.SIGINT, _on_signal)
    signal.signal(signal.SIGHUP, _on_signal)

    src = os.path.expanduser(args.source)
    base = {"source": args.source}
    if not os.path.isfile(src):
        fail(base, "missing source", permanent=True)
    if dm.kind_of(src) != "video":
        fail(base, "not a video", permanent=True)
    if args.model not in DIS_MODELS:
        fail(base, f"model {args.model} not supported for videos", permanent=True)
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        fail(base, "ffmpeg not found", permanent=True)

    os.makedirs(args.cache_dir, exist_ok=True)
    key = dm.cache_key(src, args.model)
    mp4 = os.path.join(args.cache_dir, key + ".matte.mp4")
    npz = os.path.join(args.cache_dir, key + ".matte.npz")
    part = os.path.join(args.cache_dir, key + ".matte.part")
    base["key"] = key

    found = dm.load_matte(args.cache_dir, key)
    if found and found[0].get("version") == MATTE_VERSION:
        try:
            os.utime(npz)
        except OSError:
            pass
        emit({**base, "ok": True, "cached": True, "matte": mp4, "matteInfo": found[0]})
        return
    if args.check:
        emit({**base, "ok": False, "error": "not generated", "permanent": False})
        return

    try:
        info = probe(src)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        fail(base, f"ffprobe failed: {exc}", permanent=True)
    if info["width"] <= 0 or info["height"] <= 0 or info["frames"] <= 0:
        fail(base, "unreadable video", permanent=True)
    if info["duration"] > args.max_seconds or info["frames"] > MAX_FRAMES:
        fail(base, f"too long ({info['duration']:.0f}s > {args.max_seconds:.0f}s)", permanent=True)

    size = output_size(info["width"], info["height"])
    mw = min(MASK_W, size[0]) // 2 * 2
    mh = max(2, round(mw * size[1] / size[0]) // 2 * 2)
    os.makedirs(part, exist_ok=True)
    # A part dir from another mask geometry/model version is useless.
    stamp = os.path.join(part, "stamp.json")
    want = {"v": MATTE_VERSION, "mask": [mw, mh], "model": args.model}
    try:
        with open(stamp) as fh:
            if json.load(fh) != want:
                raise ValueError
    except (OSError, ValueError):
        shutil.rmtree(part, ignore_errors=True)
        os.makedirs(part, exist_ok=True)
        with open(stamp, "w") as fh:
            json.dump(want, fh)

    t0 = time.monotonic()
    timings = {}

    def progress(stage, n, total):
        # Segmenting is ~90% of the work on CPU; encoding the rest.
        frac = n / max(1, total)
        overall = 0.9 * frac if stage == "segment" else 0.9 + 0.1 * frac
        emit({"progress": round(min(overall, 0.999), 4), "stage": stage, "frame": n, "frames": total})

    try:
        session, provider = make_session(model_path(args.model, args.models_dir), args.provider)
    except Exception as exc:  # noqa: BLE001
        fail(base, f"could not load model: {exc}")
    progress("segment", 0, info["frames"])
    try:
        count = segment(src, part, info, session, (mw, mh), progress)
    except Exception as exc:  # noqa: BLE001
        fail(base, f"segmentation failed: {exc}")
    del session
    timings["segment"] = round(time.monotonic() - t0, 1)
    if count <= 0:
        fail(base, "no frames decoded", permanent=True)
    if count != info["frames"]:
        info["frames"] = count  # trust the decoder over the container

    t1 = time.monotonic()
    tmp = os.path.join(args.cache_dir, key + ".matte.tmp.mp4")
    try:
        stack = encode(src, tmp, info, size, (mw, mh), smooth_masks(part, count, (mw, mh)), count, progress)
    except Exception as exc:  # noqa: BLE001
        try:
            os.remove(tmp)
        except OSError:
            pass
        fail(base, f"encoding failed: {exc}")
    timings["encode"] = round(time.monotonic() - t1, 1)

    import numpy as np
    ow, oh, ph = size
    meta = {
        "version": MATTE_VERSION,
        "model": args.model,
        "provider": provider,
        "source": src,
        "width": ow,                 # content size of each half
        "height": oh,
        "paddedHeight": ph,          # each half's height in the stream
        "fps": info["fps"],
        "frames": count,
        "duration": count / info["fps"],
        "maskStep": max(1, -(-count // STACK_FRAMES)),
        "seconds": timings,
    }
    tmp_npz = npz + ".tmp.npz"
    np.savez_compressed(tmp_npz, info=np.array(json.dumps(meta)), masks=stack)
    os.replace(tmp, mp4)
    os.replace(tmp_npz, npz)
    shutil.rmtree(part, ignore_errors=True)
    prune_mattes(args.cache_dir, MATTES_KEEP)
    meta["file"] = mp4
    emit({**base, "ok": True, "cached": False, "matte": mp4, "matteInfo": meta,
          "bytes": os.path.getsize(mp4)})


if __name__ == "__main__":
    main()
