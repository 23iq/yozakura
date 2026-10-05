#!/usr/bin/env bash
# Sets up fully local voice input (speech-to-text) for the shell: builds
# whisper.cpp from source (CUDA when available, CPU otherwise) and downloads
# the multilingual large-v3-turbo model plus the Silero VAD model. No sudo,
# nothing leaves the machine at runtime. Safe to re-run.
#
#   scripts/voice_setup.sh [--cpu] [--force] [--model q5_0|q8_0|all]
#
# --cpu     skip the CUDA build (CPU-only whisper.cpp, much slower).
# --force   wipe the build tree and rebuild from scratch.
# --model   which quantisation of large-v3-turbo to download (default q5_0;
#           "all" fetches both so they can be compared in Settings).
#
# If the CUDA build fails the script falls back to a CPU build automatically.
#
# Layout (must match backend/pkg/svc/voice/paths.go):
#   <data dir>/whisper/bin/whisper-server   persistent HTTP server
#   <data dir>/whisper/bin/whisper-cli      one-shot CLI (tests)
#   <data dir>/whisper/models/*.bin         ggml models
#   <data dir>/whisper/BUILD_INFO           backend=cuda|cpu, version
set -euo pipefail

# shellcheck source=scripts/lib/brand.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/brand.sh"

WHISPER_VERSION="$(brand_env WHISPER_VERSION v1.9.4)"
WHISPER_REPO="https://github.com/ggml-org/whisper.cpp"
HF_MODELS="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
HF_VAD="https://huggingface.co/ggml-org/whisper-vad/resolve/main"
VAD_MODEL="ggml-silero-v6.2.0.bin"

DATA_DIR="$BRAND_DATA_DIR"
ROOT="$DATA_DIR/whisper"
SRC="$ROOT/src"
BUILD="$ROOT/build"
BIN="$ROOT/bin"
MODELS="$ROOT/models"

CPU=0
FORCE=0
MODEL="q5_0"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpu) CPU=1 ;;
        --force) FORCE=1 ;;
        --model) shift; MODEL="${1:-}" ;;
        --model=*) MODEL="${1#--model=}" ;;
        -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
        *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done
case "$MODEL" in
    q5_0|q8_0|all) ;;
    *) printf 'unknown model: %s (q5_0|q8_0|all)\n' "$MODEL" >&2; exit 2 ;;
esac

info() { printf '\033[0;34m::\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[0;33m!!\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[0;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

for tool in git cmake curl; do
    command -v "$tool" >/dev/null || fail "$tool is required"
done
GENERATOR=()
command -v ninja >/dev/null && GENERATOR=(-G Ninja)
JOBS="$(( $(nproc) > 2 ? $(nproc) / 2 : 1 ))"

mkdir -p "$ROOT" "$BIN" "$MODELS"

# --- source ------------------------------------------------------------------
if [[ "$FORCE" == "1" ]]; then
    info "Removing previous build tree"
    rm -rf -- "$BUILD"
fi
if [[ ! -d "$SRC/.git" ]]; then
    info "Cloning whisper.cpp $WHISPER_VERSION"
    git clone --depth 1 --branch "$WHISPER_VERSION" "$WHISPER_REPO" "$SRC"
else
    current="$(git -C "$SRC" describe --tags --exact-match 2>/dev/null || true)"
    if [[ "$current" != "$WHISPER_VERSION" ]]; then
        info "Updating whisper.cpp to $WHISPER_VERSION"
        git -C "$SRC" fetch --depth 1 origin "refs/tags/$WHISPER_VERSION:refs/tags/$WHISPER_VERSION"
        git -C "$SRC" checkout -q "$WHISPER_VERSION"
        rm -rf -- "$BUILD"
    fi
fi

# --- build -------------------------------------------------------------------
COMMON=(
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=OFF
    -DWHISPER_BUILD_TESTS=OFF
    -DWHISPER_BUILD_EXAMPLES=ON
    -DWHISPER_SDL2=OFF
    -DGGML_NATIVE=ON
)

find_nvcc() {
    if command -v nvcc >/dev/null; then command -v nvcc; return; fi
    for d in "${CUDA_HOME:-}" /opt/cuda /usr/local/cuda; do
        [[ -n "$d" && -x "$d/bin/nvcc" ]] && { printf '%s\n' "$d/bin/nvcc"; return; }
    done
}

build_cuda() {
    local nvcc host=()
    nvcc="$(find_nvcc)"
    [[ -n "$nvcc" ]] || { warn "nvcc not found"; return 1; }
    # nvcc rejects host compilers newer than it knows; prefer the newest
    # versioned g++ that works, falling back to the default one.
    for cxx in g++ g++-15 g++-14 g++-13; do
        command -v "$cxx" >/dev/null || continue
        if printf 'int main(){}\n' >"$ROOT/.probe.cu" \
            && "$nvcc" -ccbin "$cxx" -o "$ROOT/.probe" "$ROOT/.probe.cu" >/dev/null 2>&1; then
            host=(-DCMAKE_CUDA_HOST_COMPILER="$(command -v "$cxx")")
            break
        fi
    done
    rm -f "$ROOT/.probe" "$ROOT/.probe.cu"
    [[ ${#host[@]} -gt 0 ]] || { warn "no host compiler accepted by $nvcc"; return 1; }
    info "Configuring CUDA build ($nvcc, ${host[0]#*=})"
    cmake -S "$SRC" -B "$BUILD/cuda" "${GENERATOR[@]}" "${COMMON[@]}" \
        -DGGML_CUDA=ON -DCMAKE_CUDA_COMPILER="$nvcc" "${host[@]}" \
        -DCMAKE_CUDA_ARCHITECTURES="$(brand_env CUDA_ARCH native)" >&2 || return 1
    info "Building (CUDA, $JOBS jobs; this takes a few minutes)"
    cmake --build "$BUILD/cuda" -j "$JOBS" --target whisper-server whisper-cli >&2 || return 1
    printf '%s\n' "$BUILD/cuda"
}

build_cpu() {
    info "Configuring CPU build"
    cmake -S "$SRC" -B "$BUILD/cpu" "${GENERATOR[@]}" "${COMMON[@]}" -DGGML_CUDA=OFF >&2
    info "Building (CPU, $JOBS jobs)"
    cmake --build "$BUILD/cpu" -j "$JOBS" --target whisper-server whisper-cli >&2
    printf '%s\n' "$BUILD/cpu"
}

BACKEND="cpu"
OUT=""
if [[ "$CPU" == "0" ]]; then
    if OUT="$(build_cuda)"; then
        BACKEND="cuda"
    else
        warn "CUDA build failed; falling back to CPU"
        OUT=""
    fi
fi
[[ -n "$OUT" ]] || OUT="$(build_cpu)"

for exe in whisper-server whisper-cli; do
    install -m 0755 "$OUT/bin/$exe" "$BIN/$exe"
done
printf 'backend=%s\nversion=%s\n' "$BACKEND" "$WHISPER_VERSION" >"$ROOT/BUILD_INFO"
info "Installed whisper.cpp ($BACKEND) into $BIN"

# --- models ------------------------------------------------------------------
fetch() {
    local url="$1" dst="$2"
    if [[ -s "$dst" ]]; then
        info "Model present: $(basename "$dst")"
        return
    fi
    info "Downloading $(basename "$dst")"
    curl -fL --retry 3 -C - -o "$dst.part" "$url"
    mv -f -- "$dst.part" "$dst"
}

models=()
case "$MODEL" in
    all) models=(q5_0 q8_0) ;;
    *) models=("$MODEL") ;;
esac
for q in "${models[@]}"; do
    fetch "$HF_MODELS/ggml-large-v3-turbo-$q.bin" "$MODELS/ggml-large-v3-turbo-$q.bin"
done
fetch "$HF_VAD/$VAD_MODEL" "$MODELS/$VAD_MODEL"

info "Done. Enable voice input in Settings > System > Voice."
