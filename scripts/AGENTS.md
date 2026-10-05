# SCRIPTS KNOWLEDGE BASE

## OVERVIEW
Remaining Bash utilities. All Python and most Bash logic has moved into the Go backend (`backend/`): services (`systemmonitor`, `sleep`, `weather`, `clipboard`, `network`, `brightness`, `config`, `keystore`, `linkpreview`, `screenshot`, `recorder`) and CLI subcommands (`colorpicker`, `ocr`, `qr`, `lockwall`, `thumbs`, `dthumbs`, `chatlist`, `writeshader`). The scripts below are thin external-tool wrappers kept for compositor/tooling edge cases.

## WHERE TO LOOK
| Script | Language | Called By | Role |
|--------|----------|-----------|------|
| `google_lens.sh` | Bash | ToolsMenu / Screenshot svc | Google Lens image search (takes image path as $1) |
| `brightness_list.sh` | Bash | Go brightness cmd | Enumerates available brightness devices |
| `sddm-sync.sh` | Bash | `modules/theme/SddmGenerator.qml` | Copies wallpaper frame, blurred copy, avatar, user fonts and resolved palette to `/var/lib/yozakura-sddm` for the SDDM theme (`assets/sddm/yozakura`); no-op if not installed |
| `install-sddm-theme.sh` / `uninstall-sddm-theme.sh` | Bash (root) | User, manually | Install/remove the `yozakura` SDDM theme, data dir and `/etc/sddm.conf.d/yozakura-theme.conf` |
| `depth_setup.sh` | Bash | User / `install.sh` (opt-in) | Creates `~/.local/share/yozakura/venv-depth` (uv, Python 3.12, `rembg[cpu]`, or `--gpu`: onnxruntime-gpu + pip CUDA/cuDNN) and downloads the `isnet-anime` model |
| `voice_setup.sh` | Bash | User (opt-in) | Builds whisper.cpp (pinned tag, CUDA with automatic CPU fallback, `--cpu` to force) into `~/.local/share/yozakura/whisper/{bin,models}` and downloads `large-v3-turbo` (`--model q5_0|q8_0|all`) + Silero VAD. Used by `backend/pkg/svc/voice` (whisper-server on 127.0.0.1, started on demand) |
| `depth_mask.py` | Python (venv-depth) | `DepthMaskService` | Wallpaper → RGBA subject cutout + per-screen placement grid (subject coverage + luminance, hex bytes; scored per clock style in `modules/desktop/clockstyles/ClockPlacement.js`) in `~/.cache/yozakura/depth/` (cached per path+mtime). For videos with a matte the grid is loop-wide (90th-percentile coverage, mean, per-pixel jitter) and the result carries `matte`/`matteInfo`. Kept in Python: rembg/onnxruntime have no Go equivalent |
| `depth_video.py` | Python (venv-depth) | `DepthMaskService` (niced, idle I/O, killable) | Video wallpaper (≤ 60 s) → `<key>.matte.mp4` (colour on top, mask luma below, same frames/fps) + `<key>.matte.npz` (placement mask stack). Segments every frame (CUDA if onnxruntime-gpu works, else CPU), temporal median + feather, x264 crf 18. Resumable via `<key>.matte.part/`; JSON progress lines on stdout |

## MIGRATED (removed from scripts/)
| Former script | Go equivalent |
|---------------|---------------|
| `system_monitor.py` | `svc/systemmonitor` (IPC) |
| `weather.sh` | `svc/weather` (IPC) |
| `clipboard_watch.sh` | `svc/clipboard` watch (IPC) |
| `clipboard_check.sh`, `clipboard_insert.sh` | `svc/clipboard` native capture+insert (encrypted SQLite via ncruces driver) |
| `sleep_monitor.sh`, `loginlock.sh` | `svc/sleep` (IPC) |
| `daemon_priority.sh` | CLI `runShell()` |
| `keystore.py` | `svc/keystore` (IPC) |
| `link_preview.py` | `svc/linkpreview` (IPC) |
| `colorpicker.py` + old colorpicker path | CLI `yozakura colorpicker` (DMS loupe, wlr-screencopy) |
| `lockwall.py` | CLI `yozakura lockwall` |
| `thumbgen.py` | CLI `yozakura thumbs` |
| `desktop_thumbgen.py` | CLI `yozakura dthumbs` |
| `ocr.sh` | CLI `yozakura ocr [langs]` |
| `qr_scan.sh` | CLI `yozakura qr` |
| `wf-record.sh` | IPC `recorder.start/stop` (gpu-screen-recorder owned by backend) |

## CONVENTIONS
- **Communication**: Scripts output to stdout; QML reads via `Process` + `SplitParser` or `StdioCollector`.
- **Format**: Bash scripts output line-delimited text.
- **Dependencies**: Scripts assume tools are installed (`wl-paste`, `wl-copy`, `tesseract`, `brightnessctl`). Nix/install.sh handles dependencies. Screenshots/recording/colorpicker/OCR/QR no longer need grim, ImageMagick, zbar or slurp (region selection reuses the QML screenshot overlay; QR/barcodes decode in pure Go via gozxing).
- **Error handling**: Scripts should exit cleanly on missing tools; QML services provide fallback values.
