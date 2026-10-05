#!/usr/bin/env bash
# Session diagnostics for "the shell does not start / binds do nothing".
# Works from a terminal or a text console (Ctrl+Alt+F3), even while piped
# from curl:
#
#   curl -sL https://raw.githubusercontent.com/23iq/yozakura/main/scripts/diag.sh | bash
#
# Collects versions, the compositor config wiring, the generated autostart
# and binds, then starts the shell once (if it is not running) and captures
# its log. The report is saved to ~/yozakura-diag.txt and, unless
# NO_UPLOAD=1, uploaded to paste.rs so only a short link has to be shared.

APP="yozakura"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/$APP"
BIN="${YOZAKURA_BIN_DIR:-$HOME/.local/bin}/$APP"
SRC="$(cat "$DATA/shell_repo" 2>/dev/null || echo "$HOME/.local/src/$APP")"
OUT="$HOME/$APP-diag.txt"

# From a text console the graphical session's sockets are not in the
# environment; borrow them from the running compositor.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  WAYLAND_DISPLAY="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-[0-9]' -printf '%f\n' 2>/dev/null | head -1)"
  export WAYLAND_DISPLAY
fi
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -d "$XDG_RUNTIME_DIR/hypr" ]]; then
  HYPRLAND_INSTANCE_SIGNATURE="$(find "$XDG_RUNTIME_DIR/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' | sort -nr | head -1 | cut -d' ' -f2)"
  export HYPRLAND_INSTANCE_SIGNATURE
fi

section() { printf '\n== %s\n' "$1"; }
show() { [[ -f "$1" ]] && grep -n "$2" "$1" | head -"${3:-10}"; }

{
  section "system"
  date
  grep -m1 PRETTY_NAME /etc/os-release
  echo "shell=$SHELL wayland=${WAYLAND_DISPLAY:-none} hypr=${HYPRLAND_INSTANCE_SIGNATURE:+yes}"

  section "versions"
  git -C "$SRC" log --oneline -1 2>&1
  git -C "$SRC" status --short 2>&1 | head -10
  ls -la "$BIN" "${BIN%/*}/yozd" 2>&1
  "$BIN" version 2>&1
  command -v qs quickshell Hyprland niri mango 2>&1
  qs --version 2>&1 | head -1
  hyprctl version 2>&1 | head -1

  section "session PATH (compositor)"
  for c in Hyprland niri mango; do
    pid="$(pgrep -x "$c" | head -1)"
    [[ -n "$pid" ]] && echo "$c: $(tr '\0' '\n' <"/proc/$pid/environ" | grep '^PATH=')"
  done

  section "running"
  pgrep -a 'qs|quickshell|yozd|yozakura' | cut -c1-150

  section "compositor config"
  ls -la "$HOME/.config/hypr" 2>&1
  show "$HOME/.config/hypr/hyprland.conf" "$APP\|^source"
  show "$HOME/.config/hypr/hyprland.lua" "$APP\|loadfile\|dofile"
  hyprctl configerrors 2>&1 | head -15

  section "generated autostart"
  for f in hyprland.conf hyprland.lua hyprland.yozd.conf hyprland.yozd.lua; do
    show "$DATA/$f" "exec" 4 | sed "s|^|$f:|"
  done

  section "super binds"
  show "$DATA/hyprland.yozd.conf" "Super_L" 3
  show "$DATA/yozd.toml" "Super_L" 3
  grep -n -B4 -A4 'Super_L' "$DATA/yozd.toml" 2>/dev/null | grep -i modifiers
  hyprctl binds 2>/dev/null | grep -i -B3 -A6 'super_l' | head -20

  section "doctor"
  "$BIN" doctor 2>&1 | tail -30

  section "shell start"
  if pgrep -f "qs .*shell.qml" >/dev/null; then
    echo "shell already running"
  elif [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "no Wayland session found; not starting the shell"
  else
    log="$HOME/$APP-run.log"
    setsid -f "$BIN" >"$log" 2>&1 </dev/null
    sleep 15
    if pgrep -f "qs .*shell.qml" >/dev/null; then echo "STARTED OK (still running after 15s)"; else echo "DID NOT START"; fi
    tail -60 "$log"
  fi

  section "install log"
  tail -25 "$HOME/.cache/$APP/install.log" 2>&1
} >"$OUT" 2>&1

echo
echo "Report saved to $OUT"
grep -A1 "== shell start" "$OUT" | tail -1
if [[ "${NO_UPLOAD:-0}" != 1 ]] && command -v curl >/dev/null; then
  url="$(curl -fsS --max-time 20 --data-binary @"$OUT" https://paste.rs 2>/dev/null)"
  if [[ -n "$url" ]]; then
    printf '\n  Send this link:\n\n      \033[1m%s\033[0m\n\n' "$url"
  else
    echo "Upload failed; send the file $OUT instead."
  fi
fi
