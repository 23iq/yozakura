#!/usr/bin/env bash
# Sets up the optional foreground-mask backend for the desktop depth clock:
# an isolated Python venv with rembg (CPU onnxruntime) plus the isnet-anime
# model. Safe to re-run; pass --force to rebuild the venv from scratch.
#
#   scripts/depth_setup.sh [--force] [--gpu]
#
# --gpu installs onnxruntime-gpu with pip-packaged CUDA/cuDNN (~2.5 GB) for
# NVIDIA cards. Video wallpaper mattes (depth_video.py) then take ~1 min per
# 30 s of video instead of ~6 min on CPU. Run without --gpu to go back.
#
# Layout (must match DepthMaskService.qml):
#   <data dir>/venv-depth         venv (python + rembg)
#   <data dir>/depth-models     downloaded model weights (~180 MB)
set -euo pipefail

# shellcheck source=scripts/lib/brand.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/brand.sh"

DATA_DIR="$BRAND_DATA_DIR"
VENV="$DATA_DIR/venv-depth"
MODELS="$DATA_DIR/depth-models"
MODEL="$(brand_env DEPTH_MODEL isnet-anime)"
PY_VERSION="3.12"
FORCE=0
GPU=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --gpu) GPU=1 ;;
        *) printf 'unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done
if [[ "$GPU" == "1" ]]; then
    PACKAGES=("rembg[gpu]>=2.0.60,<3" "onnxruntime-gpu[cuda,cudnn]" "pillow" "numpy")
    CONFLICT="onnxruntime"
    RUNTIME="onnxruntime-gpu"
else
    PACKAGES=("rembg[cpu]>=2.0.60,<3" "pillow" "numpy")
    CONFLICT="onnxruntime-gpu"
    RUNTIME="onnxruntime"
fi

info() { printf '\033[0;34m::\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[0;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "$FORCE" == "1" && -d "$VENV" ]]; then
    info "Removing existing venv $VENV"
    rm -rf -- "$VENV"
fi

mkdir -p "$DATA_DIR" "$MODELS"

UV="$(command -v uv || true)"
[[ -z "$UV" && -x "$HOME/.local/bin/uv" ]] && UV="$HOME/.local/bin/uv"

if [[ ! -x "$VENV/bin/python" ]]; then
    if [[ -n "$UV" ]]; then
        info "Creating venv with uv (Python $PY_VERSION) at $VENV"
        "$UV" venv --python "$PY_VERSION" "$VENV"
    else
        command -v python3 >/dev/null || fail "python3 (or uv) is required"
        info "Creating venv with python3 -m venv at $VENV"
        python3 -m venv "$VENV"
    fi
fi

info "Installing ${PACKAGES[*]}"
# onnxruntime and onnxruntime-gpu ship the same module: never keep both.
if [[ -n "$UV" ]]; then
    VIRTUAL_ENV="$VENV" "$UV" pip uninstall --python "$VENV/bin/python" "$CONFLICT" >/dev/null 2>&1 || true
    # Reinstalled: removing the other package may have deleted shared files.
    VIRTUAL_ENV="$VENV" "$UV" pip install --python "$VENV/bin/python" --reinstall-package "$RUNTIME" "${PACKAGES[@]}"
else
    "$VENV/bin/python" -m pip uninstall -y "$CONFLICT" >/dev/null 2>&1 || true
    "$VENV/bin/python" -m pip install --upgrade pip
    "$VENV/bin/python" -m pip install "${PACKAGES[@]}"
fi

command -v ffmpeg >/dev/null || info "ffmpeg not found: video wallpapers will be skipped"

if [[ "$GPU" == "1" ]]; then
    info "Checking CUDA inference"
    "$VENV/bin/python" -c "import onnxruntime as o; o.preload_dlls(); print(o.get_available_providers())" \
        || info "onnxruntime-gpu does not load; depth jobs fall back to CPU"
fi

info "Downloading model '$MODEL' into $MODELS"
U2NET_HOME="$MODELS" "$VENV/bin/python" -c "from rembg import new_session; new_session('$MODEL')"

info "Depth clock backend ready. Change the wallpaper (or restart the shell) to generate masks."
