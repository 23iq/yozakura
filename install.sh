#!/usr/bin/env bash
# Yozakura installer and updater.
#
#   curl -fsSL https://raw.githubusercontent.com/23iq/yozakura/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --compositor niri --yes
#
# It installs the core (the shell, one compositor, a login screen) and shows
# the full plan first; apps, voice and the rest come from the setup wizard
# on the first login. --dry-run walks the same flow and only shows what each
# step would run. Re-running it updates an
# existing install; `yozakura update` runs the checkout's copy with --update.
# The package list is backend/pkg/deps/packages.tsv (shared with
# `yozakura doctor`). Run with --help for every option.
#
# Everything lives in functions and runs from the last line, so a truncated
# download never runs half a script, and `git pull` rewriting this file while
# it runs (--update) does not affect the copy bash already parsed.

set -euo pipefail

# === Identity and defaults (overridable through the environment) ===
APP_ID="yozakura"
DISPLAY_NAME="Yozakura"
LEGACY_ID="ambxst"
DAEMON_ID="yozd"
REPO_URL="${YOZAKURA_REPO_URL:-https://github.com/23iq/yozakura.git}"
BRANCH="${YOZAKURA_BRANCH:-}"
RAW_BASE="${YOZAKURA_RAW_BASE:-https://raw.githubusercontent.com/23iq/yozakura/${BRANCH:-main}}"
FLAKE_URI="${YOZAKURA_FLAKE:-github:23iq/yozakura}"
SRC_DIR="${YOZAKURA_SRC:-$HOME/.local/src/$APP_ID}"
BIN_DIR="${YOZAKURA_BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APP_ID"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$APP_ID"
LOG_FILE="$LOG_DIR/install.log"
DEPS_PATH="backend/pkg/deps/packages.tsv"
FEDORA_COPR="lionheartp/Hyprland"
PHOSPHOR_VERSION="2.1.2"
SYS_BIN="${YOZAKURA_SYS_BIN:-/usr/local/bin}"
# Root-owned copy of the binary that pkexec runs for the setup wizard's app
# installs: user-level code cannot replace it (unlike ~/.local/bin).
SYS_HELPER="/usr/local/lib/$APP_ID/$APP_ID-sys"
OS_RELEASE="${YOZAKURA_OS_RELEASE:-/etc/os-release}"
COMPOSITORS=(hyprland niri mango)

WITH_VOICE="" WITH_DEPTH="" WITH_SDDM="" REBOOT="" # "" = default, 1 = yes, 0 = no
INSTALL_DEPS=1 UPDATE_ONLY=0 ASSUME_YES=0 COMP_CONFIG=1 DRY_RUN=0 VERBOSE=0 USE_AUR=1 EXCLUSIVE=0
COMPOSITOR="" PREV_INSTALL=0 LEGACY_PENDING=0 FAILED=()
TTY="" DISTRO="" DISTRO_NAME="" GPU="" DM="" SUDO_OK=0 SUDO_FAILED=0 KEEPALIVE_PID=""
DEPS_TSV=""
PKGS=() AUR_PKGS=() SERVICES=() LINK_BINS=0 ADD_INPUT_GROUP=0 AUR_HELPER="" REPO_ACTION=""

# === Output ===
# Everything is written to stderr, so stderr decides: colour depth (truecolor,
# 256, 16 or none), UTF-8 glyphs or ASCII, and the width. NO_COLOR and
# TERM=dumb turn colour off; a non-UTF-8 locale gets ASCII art.
UI_COLOR=0 UI_UTF8=0 UI_COLS=80 UI_W=80 UI_OUT="" UI_R=0 UI_G=0 UI_B=0

detect_output() {
  local n loc probe='█'
  if [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    case "${COLORTERM:-}" in
    truecolor | 24bit) UI_COLOR=24 ;;
    *)
      n="$(tput colors 2>/dev/null || true)"
      if [[ "$n" =~ ^[0-9]+$ ]] && ((n >= 256)); then UI_COLOR=256; else UI_COLOR=16; fi
      ;;
    esac
  fi
  # Both the locale and bash itself must agree on UTF-8: when the locale is
  # not installed, bash counts bytes and the art would be cut mid-character.
  loc="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
  [[ "${loc,,}" =~ utf-?8 && ${#probe} -eq 1 ]] && UI_UTF8=1
  n="${COLUMNS:-}"
  [[ "$n" =~ ^[0-9]+$ ]] || n="$( (stty size </dev/tty) 2>/dev/null || true)" n="${n#* }"
  [[ "$n" =~ ^[0-9]+$ ]] || n="$(tput cols 2>/dev/null || true)"
  [[ "$n" =~ ^[0-9]+$ && "$n" -ge 20 ]] && UI_COLS="$n"
  UI_W=$((UI_COLS < 92 ? UI_COLS - 2 : 90))
}

# ui_c6 V: REPLY = the 6x6x6 cube level of a channel (xterm: 0,95,135,..).
ui_c6() { if (($1 < 48)); then REPLY=0; elif (($1 < 115)); then REPLY=1; else REPLY=$((($1 - 35) / 40)); fi; }

# ui_rgb R G B [16-colour SGR]: UI_OUT = the foreground escape at this depth.
ui_rgb() {
  case "$UI_COLOR" in
  24) printf -v UI_OUT '\033[38;2;%d;%d;%dm' "$1" "$2" "$3" ;;
  256)
    local c=16
    ui_c6 "$1" && c=$((c + 36 * REPLY))
    ui_c6 "$2" && c=$((c + 6 * REPLY))
    ui_c6 "$3" && c=$((c + REPLY))
    printf -v UI_OUT '\033[38;5;%dm' "$c"
    ;;
  16) printf -v UI_OUT '\033[%sm' "${4:-35}" ;;
  *) UI_OUT="" ;;
  esac
}

# Brand colours: the petal gradient of the logo (#f4a7c0 -> #d4709a), led in
# by a paler blossom tone so the art reads as lit from the top left.
GRADIENT=(255 220 232 244 167 192 200 92 142)

# ui_grad T: UI_R/G/B = the gradient at T (0..1000).
ui_grad() {
  local t="$1" a=0
  ((t < 0)) && t=0
  ((t > 1000)) && t=1000
  if ((t > 500)); then a=3 t=$((t - 500)); fi
  t=$((t * 2))
  UI_R=$((GRADIENT[a] + (GRADIENT[a + 3] - GRADIENT[a]) * t / 1000))
  UI_G=$((GRADIENT[a + 1] + (GRADIENT[a + 4] - GRADIENT[a + 1]) * t / 1000))
  UI_B=$((GRADIENT[a + 2] + (GRADIENT[a + 5] - GRADIENT[a + 2]) * t / 1000))
}

# The same gradient as a 256-colour ladder: the cube cannot interpolate
# pinks smoothly, so a few hand-picked steps read better than rounding.
GRADIENT_256=(224 218 211 175 168)

# ui_paint TEXT X Y W H: UI_OUT = TEXT coloured cell by cell along the
# diagonal gradient of a W x H canvas whose column X, row Y TEXT starts at.
ui_paint() {
  local text="$1" x="$2" y="$3" w="$4" h="$5" i t ch last="" out=""
  if [[ "$UI_COLOR" == 0 ]]; then
    UI_OUT="$text"
    return
  fi
  for ((i = 0; i < ${#text}; i++)); do
    ch="${text:i:1}"
    if [[ "$ch" != " " ]]; then
      t=$((((x + i) * 2000 / w + y * 1000 / h) / 3))
      case "$UI_COLOR" in
      24) ui_grad "$t" && ui_rgb "$UI_R" "$UI_G" "$UI_B" ;;
      256) printf -v UI_OUT '\033[38;5;%dm' "${GRADIENT_256[t * 5 / 1001]}" ;;
      *) ((t < 500)) && UI_OUT=$'\033[95m' || UI_OUT=$'\033[35m' ;;
      esac
      [[ "$UI_OUT" != "$last" ]] && out+="$UI_OUT" last="$UI_OUT"
    fi
    out+="$ch"
  done
  UI_OUT="$out$C_OFF"
}

# ui_strip TEXT: UI_OUT = TEXT without colour escapes (for measuring).
ui_strip() {
  local re=$'\033\\[[0-9;]*m'
  UI_OUT="$1"
  while [[ "$UI_OUT" =~ $re ]]; do UI_OUT="${UI_OUT//"${BASH_REMATCH[0]}"/}"; done
}

ui_init() {
  detect_output
  C_OFF="" C_BOLD="" C_DIM="" C_LINE="" C_PINK="" C_ROSE="" C_GREEN="" C_YELLOW="" C_RED=""
  if [[ "$UI_COLOR" != 0 ]]; then
    C_OFF=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_LINE=$'\033[2m'
    # Rules and frames: a muted plum where there are enough colours.
    [[ "$UI_COLOR" != 16 ]] && ui_rgb 112 76 98 && C_LINE="$UI_OUT"
    ui_rgb 244 167 192 95 && C_PINK="$UI_OUT"
    ui_rgb 212 112 154 35 && C_ROSE="$UI_OUT"
    ui_rgb 134 214 166 32 && C_GREEN="$UI_OUT"
    ui_rgb 236 196 112 33 && C_YELLOW="$UI_OUT"
    ui_rgb 240 108 124 31 && C_RED="$UI_OUT"
  fi
  if [[ "$UI_UTF8" == 1 ]]; then
    G_OK="✓" G_FAIL="✗" G_WARN="!" G_INFO="·" G_ASK="?" G_SEP="·" G_STEP="✿" G_ON="■" G_OFF="□" G_LEAD="·"
    G_SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' G_PIPE="│"
    B_H="─" B_V="│" B_TL="╭" B_TR="╮" B_BL="╰" B_BR="╯"
  else
    G_OK="+" G_FAIL="x" G_WARN="!" G_INFO="-" G_ASK="?" G_SEP="-" G_STEP="*" G_ON="[x]" G_OFF="[ ]" G_LEAD="."
    G_SPIN='|/-\|/-\|/' G_PIPE="|"
    B_H="-" B_V="|" B_TL="+" B_TR="+" B_BL="+" B_BR="+"
  fi
  # A spinner needs a terminal on stderr (it redraws its line).
  if [[ -t 2 ]]; then SPINNER=1; else SPINNER=0; fi
}
ui_init

# ui_rep N CHAR: UI_OUT = CHAR repeated N times.
ui_rep() {
  local i out=""
  for ((i = 0; i < $1; i++)); do out+="$2"; done
  UI_OUT="$out"
}

info() { printf '  %s%s%s %s\n' "$C_DIM" "$G_INFO" "$C_OFF" "$*" >&2; }
ok() { printf '  %s%s%s %s\n' "$C_GREEN" "$G_OK" "$C_OFF" "$*" >&2; }
warn() { printf '  %s%s%s %s\n' "$C_YELLOW" "$G_WARN" "$C_OFF" "$*" >&2; }
die() {
  printf '\n  %s%s %s%s\n' "$C_RED$C_BOLD" "$G_FAIL" "$1" "$C_OFF" >&2
  [[ $# -gt 1 ]] && printf '    %s\n' "${@:2}" >&2
  exit 1
}

# step TITLE: a section heading with a hairline to the right edge.
step() {
  local rule=$((UI_W - ${#1} - 6))
  ((rule < 3)) && rule=3
  ui_rep "$rule" "$B_H"
  printf '\n  %s%s%s %s%s%s %s%s%s\n' "$C_PINK" "$G_STEP" "$C_OFF" "$C_BOLD" "$1" "$C_OFF" "$C_LINE" "$UI_OUT" "$C_OFF" >&2
}

# done_line LABEL TIME: "✓ label ········ 12s".
done_line() {
  local label="$1" t="$2" dots mark="$C_GREEN$G_OK"
  # A dry run did nothing: no check mark.
  [[ "$DRY_RUN" == 1 ]] && mark="$C_DIM$G_INFO"
  dots=$((UI_W - ${#label} - ${#t} - 8))
  if ((dots < 2)); then
    printf '  %s%s %s %s%s%s\n' "$mark" "$C_OFF" "$label" "$C_DIM" "$t" "$C_OFF" >&2
    return
  fi
  ui_rep "$dots" "$G_LEAD"
  printf '  %s%s %s %s%s %s%s\n' "$mark" "$C_OFF" "$label" "$C_DIM" "$UI_OUT" "$t" "$C_OFF" >&2
}

# --- Boxes: the plan and the final screen ---
# ui_box_top TITLE / ui_box_row TEXT / ui_box_kv KEY VALUE / ui_box_head NAME /
# ui_box_bottom. Rows are padded by their visible width; a row too long for
# the box is folded as plain text.
ui_box_width() { UI_OUT=$((UI_W - 2 < 44 ? 44 : UI_W - 2)); }

ui_box_top() {
  local w
  ui_box_width && w="$UI_OUT"
  ui_rep $((w - ${#1} - 5)) "$B_H"
  printf '  %s%s%s %s%s%s%s %s%s%s\n' "$C_LINE" "$B_TL$B_H" "$C_OFF" "$C_PINK$C_BOLD" "$1" "$C_OFF" "$C_LINE" "$UI_OUT" "$B_TR" "$C_OFF" >&2
}

ui_box_bottom() {
  ui_box_width
  ui_rep $((UI_OUT - 2)) "$B_H"
  printf '  %s%s%s%s%s\n' "$C_LINE" "$B_BL" "$UI_OUT" "$B_BR" "$C_OFF" >&2
}

ui_box_row() {
  local text="$1" w vis
  ui_box_width && w=$((UI_OUT - 4))
  ui_strip "$text" && vis="$UI_OUT"
  if ((${#vis} > w)); then
    while IFS= read -r text; do ui_box_row "$text"; done < <(fold -s -w "$w" <<<"$vis")
    return
  fi
  printf '  %s%s%s %s%*s %s%s%s\n' "$C_LINE" "$B_V" "$C_OFF" "$1" $((w - ${#vis})) "" "$C_LINE" "$B_V" "$C_OFF" >&2
}

# ui_box_kv KEY VALUE [COLOUR]: a key column and a value folded under itself.
ui_box_kv() {
  local key="$1" value="$2" color="${3:-}" w vis first=1 line
  ui_box_width && w=$((UI_OUT - 4 - 13))
  ui_strip "$value" && vis="$UI_OUT"
  if ((${#vis} <= w)); then
    ui_box_row "$(printf '%s%-12s%s %s%s%s' "$C_ROSE" "$key" "$C_OFF" "$color" "$value" "${color:+$C_OFF}")"
    return
  fi
  while IFS= read -r line; do
    if [[ "$first" == 1 ]]; then
      ui_box_row "$(printf '%s%-12s%s %s%s%s' "$C_ROSE" "$key" "$C_OFF" "$color" "$line" "${color:+$C_OFF}")"
      first=0
    else
      ui_box_row "$(printf '%-12s %s%s%s' "" "$color" "$line" "${color:+$C_OFF}")"
    fi
  done < <(fold -s -w "$w" <<<"$vis")
}

ui_box_head() {
  ui_box_row ""
  ui_box_row "$C_PINK$C_BOLD$1$C_OFF"
}

# === Art ===
# The Yozakura mark: the five-petal blossom of assets/yozakura (rasterised
# into quadrant blocks, 2x2 pixels a cell) and a thin, rounded wordmark drawn
# with box-drawing lines. Only data and drawing live here.
ART_FLOWER=(
  "       ▄▄▖▗▄▄       "
  "      ▐██████▌      "
  " ▗▄▄▄▄ ▜████▛ ▄▄▄▄▖ "
  " ▝█████ ▝▀▀▘ █████▘ "
  "▐██████▌    ▐██████▌"
  " ▝▀▀▀▀        ▀▀▀▀▘ "
  "   ▗▟███▙  ▟███▙▖   "
  "  ▗██████▌▐██████▖  "
  "   ▀▀▜███▘▝███▛▀▀   "
  "      ▀▘    ▝▀      "
)
ART_FLOWER_SMALL=(
  "     ▄▄▄▄     "
  " ▗▄▖▝████▘▗▄▖ "
  " ▟██▙ ▀▀ ▟██▙ "
  "▝███▀    ▀███▘"
  "  ▗▟██▖▗██▙▖  "
  "  ▜███▌▐███▛  "
  "    ▀▀  ▀▀    "
)
ART_FLOWER_ASCII=(
  "    _  _    "
  "  _( \\/ )_  "
  " (_  ()  _) "
  "   (_/\\_)   "
)
# Pixel capitals in half blocks, like the blossom: a 10-pixel grid of
# square pixels (a cell is 1 x 2) with 1-pixel strokes. Y is 7 wide and
# the rest 6, 2 apart; below 90 columns every letter is 5 wide.
ART_WORD=(
  "▀▄   ▄▀  ▄▀▀▀▀▄  ▀▀▀▀▀█  ▄▀▀▀▀▄  █   ▄▀  █    █  █▀▀▀▀▄  ▄▀▀▀▀▄"
  "  ▀▄▀    █    █      █   █    █  █ ▄▀    █    █  █    █  █    █"
  "   █     █    █    ▄▀    █▄▄▄▄█  ██      █    █  █▄▄▄▄▀  █▄▄▄▄█"
  "   █     █    █   █      █    █  █ ▀▄    █    █  █ ▀▄    █    █"
  "   █     ▀▄▄▄▄▀  █▄▄▄▄▄  █    █  █   ▀▄  ▀▄▄▄▄▀  █   ▀▄  █    █"
)
ART_WORD_NARROW=(
  "▀▄ ▄▀  ▄▀▀▀▄  ▀▀▀▀█  ▄▀▀▀▄  █  ▄▀  █   █  █▀▀▀▄  ▄▀▀▀▄"
  "  █    █   █     █   █   █  █ █    █   █  █   █  █   █"
  "  █    █   █    █    █▄▄▄█  ██     █   █  █▄▄▄▀  █▄▄▄█"
  "  █    █   █   █     █   █  █ █    █   █  █ ▀▄   █   █"
  "  █    ▀▄▄▄▀  █▄▄▄▄  █   █  █  ▀▄  ▀▄▄▄▀  █  ▀▄  █   █"
)
ART_KANJI="夜桜"
ART_TAGLINE="desktop shell for Hyprland, niri and Mango"

# art_version: the version of an existing checkout, if there is one.
art_version() {
  local v=""
  [[ -r "$SRC_DIR/version" ]] && v="$(head -n1 "$SRC_DIR/version" 2>/dev/null)"
  UI_OUT="${v:+v$v}"
}

# art_emit LINE: one line of art, with a short pause while animating.
art_emit() {
  printf '%s\n' "$1" >&2
  [[ "$UI_ANIM" == 1 ]] && sleep 0.035
  return 0
}

# art_brush WIDTH [ROOM]: UI_OUT = the brush stroke under the wordmark: a stroke
# a little heavier than the letters that thins out and fades past its end,
# like the logo's underline.
art_brush() {
  local tail=$(($1 / 5)) stroke
  [[ -n "${2:-}" ]] && ((tail > $2)) && tail=$2
  ((tail < 0)) && tail=0
  ui_rep $(($1 - 1)) "▂" && stroke="▁$UI_OUT"
  ui_paint "$stroke" 0 1 "$1" 2 && stroke="$UI_OUT"
  ui_rep "$tail" "▁"
  UI_OUT="$stroke$C_LINE$UI_OUT$C_OFF"
}

banner() {
  local ver
  art_version && ver="$UI_OUT"
  # A ≤0.4 s line-by-line reveal, only for a person at a colour terminal.
  UI_ANIM=0
  [[ "$UI_COLOR" != 0 && -n "$TTY" && "$ASSUME_YES" == 0 && -z "${CI:-}" ]] && UI_ANIM=1
  echo >&2
  if [[ "$UI_UTF8" == 0 ]]; then
    banner_ascii "$ver"
  elif ((UI_COLS < 80)); then
    banner_compact "$ver"
  else
    banner_full "$ver"
  fi
  echo >&2
}

# The blossom (10 rows) beside the wordmark, its underline and the tagline.
banner_full() {
  local i rows=${#ART_FLOWER[@]} words=("${ART_WORD[@]}") flower right=() w
  ((UI_COLS < 90)) && words=("${ART_WORD_NARROW[@]}")
  w=${#words[0]}
  for ((i = 0; i < ${#words[@]}; i++)); do
    ui_paint "${words[i]}" 0 "$i" "$w" "${#words[@]}" && right[i + 1]="$UI_OUT"
  done
  art_brush "$w" $((UI_COLS - w - 26)) && right[6]="$UI_OUT"
  # The version goes where it fits beside the tagline.
  local ver="$1"
  ((UI_COLS < 2 + 20 + 3 + 6 + ${#ART_TAGLINE} + 5 + ${#ver})) && ver=""
  ui_paint "$ART_KANJI" 0 0 4 1 && right[8]="$C_BOLD$UI_OUT  $C_DIM$ART_TAGLINE${ver:+  $G_SEP  $ver}$C_OFF"
  for ((i = 0; i < rows; i++)); do
    ui_paint "${ART_FLOWER[i]}" 0 "$i" "${#ART_FLOWER[0]}" "$rows" && flower="$UI_OUT"
    art_emit "  $flower   ${right[i]:-}"
  done
}

# Under 80 columns: the small blossom, a letter-spaced name and the tagline.
banner_compact() {
  local i rows=${#ART_FLOWER_SMALL[@]} flower right=() word="Y O Z A K U R A"
  ui_paint "$word" 0 0 "${#word}" 1 && right[2]="$C_BOLD$UI_OUT"
  art_brush "${#word}" && right[3]="$UI_OUT"
  ui_paint "$ART_KANJI" 0 0 4 1 && right[4]="$C_BOLD$UI_OUT  ${C_DIM}${ART_TAGLINE#desktop }$C_OFF"
  for ((i = 0; i < rows; i++)); do
    ui_paint "${ART_FLOWER_SMALL[i]}" 0 "$i" "${#ART_FLOWER_SMALL[0]}" "$rows" && flower="$UI_OUT"
    art_emit "  $flower   ${right[i]:-}"
  done
}

banner_ascii() {
  local i right=("" "${C_PINK}${C_BOLD}Y O Z A K U R A$C_OFF" "${C_DIM}night-sakura $ART_TAGLINE$C_OFF" "${1:+$C_DIM$1$C_OFF}")
  for ((i = 0; i < ${#ART_FLOWER_ASCII[@]}; i++)); do
    art_emit "  $C_PINK${ART_FLOWER_ASCII[i]}$C_OFF  ${right[i]}"
  done
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }
# No `fc-list | grep -q`: grep exits early and pipefail turns fc-list's
# SIGPIPE into a failure.
has_phosphor() { local f; f="$(fc-list : family 2>/dev/null || true)"; [[ "${f,,}" == *phosphor* ]]; }
log() { [[ "$DRY_RUN" == 1 ]] || printf '%s\n' "$*" >>"$LOG_FILE" 2>/dev/null || true; }

# === Dry run ===
# --dry-run walks the whole flow: questions, plan and every step, but each
# command that would change something is only shown ("would run: ..."). The
# helpers below and run/run_attended/try_sudo are the only places that
# decide; reads (detection, the plan) stay real.

# dry_banner TEXT: the "DRY RUN" line at the top and the bottom.
dry_banner() {
  printf '\n  %s%s DRY RUN %s%s %s%s\n' "$C_YELLOW$C_BOLD" "$B_H$B_H" "$B_H$B_H" "$C_OFF" "$C_YELLOW" "$1$C_OFF" >&2
}

# dry_note VERB TEXT: "would VERB: TEXT", dim, under the step it belongs to;
# a long TEXT wraps between words, indented under its start.
dry_note() {
  local head="would $1: " words=() word line="" w pad
  w=$((UI_W - 8 - ${#head}))
  ((w < 24)) && w=24
  printf -v pad '%*s' "${#head}" ""
  read -ra words <<<"$2"
  for word in "${words[@]}"; do
    if [[ -n "$line" ]] && ((${#line} + 1 + ${#word} > w)); then
      printf '    %s%s %s%s%s\n' "$C_DIM" "$G_PIPE" "$head" "$line" "$C_OFF" >&2
      head="$pad" line=""
    fi
    line+="${line:+ }$word"
  done
  printf '    %s%s %s%s%s\n' "$C_DIM" "$G_PIPE" "$head" "$line" "$C_OFF" >&2
}

# done_or_would DONE WOULD: "✓ DONE", or in a dry run a dim "· would WOULD".
done_or_would() {
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  %s%s would %s%s\n' "$C_DIM" "$G_INFO" "$2" "$C_OFF" >&2
  else
    ok "$1"
  fi
}

# dry_line CMD...: shows CMD as it would run; the installer's own helper
# functions are spelled out as what they do.
dry_line() {
  local what
  [[ "$1" == retry ]] && shift
  case "$1" in
  clone_repo) printf -v what 'git clone %s%q %q' "${BRANCH:+--branch $BRANCH }" "$REPO_URL" "$SRC_DIR" ;;
  bootstrap_yay) what="git clone https://aur.archlinux.org/yay-bin.git, then makepkg -si (in a temporary dir)" ;;
  add_input_group) what="sudo usermod -aG input $(id -un) (after sudo groupadd --system input, if it is missing)" ;;
  phosphor_user_font) what="curl the Phosphor v$PHOSPHOR_VERSION zip, copy its fonts into $(tilde "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/phosphor"), fc-cache" ;;
  download_release) what="curl the latest release binaries and SHA256SUMS into $(tilde "$SRC_DIR"), verify them, chmod 755" ;;
  polkit_autostart) what="append the hyprpolkitagent autostart line to $(tilde "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/$(hypr_entry)") (if no polkit agent is configured)" ;;
  *)
    local a q="'" plain='^[][A-Za-z0-9_./=:,@%+~{}-]+$'
    what=""
    for a in "$@"; do
      # Plain words as they are, anything else single-quoted.
      [[ "$a" =~ $plain ]] || a="$q${a//$q/$q\\$q$q}$q"
      what+="${what:+ }$a"
    done
    ;;
  esac
  dry_note run "$what"
}

# would CMD...: runs CMD, or in a dry run shows it (status 0).
would() {
  if [[ "$DRY_RUN" == 1 ]]; then
    dry_line "$@"
    return 0
  fi
  "$@"
}

# logged CMD...: would, with CMD's output in the log.
logged() {
  if [[ "$DRY_RUN" == 1 ]]; then
    dry_line "$@"
    return 0
  fi
  "$@" >>"$LOG_FILE" 2>&1
}

# write_file PATH TEXT: PATH (and its directory) with TEXT, or in a dry run
# only named.
write_file() {
  if [[ "$DRY_RUN" == 1 ]]; then
    dry_note write "$(tilde "$1")"
    return 0
  fi
  mkdir -p "$(dirname "$1")" && printf '%s' "$2" >"$1"
}

# dry_end: the closing line and what to try next, the setup wizard's own
# dry run (the real one opens by itself on the first login after a reboot).
dry_end() {
  [[ "$DRY_RUN" == 1 ]] || return 0
  local cmd="" b
  if has_cmd "$APP_ID"; then
    cmd="$APP_ID"
  else
    for b in "$BIN_DIR/$APP_ID" "$SRC_DIR/$APP_ID"; do
      [[ -x "$b" ]] && cmd="$(tilde "$b")" && break
    done
  fi
  echo >&2
  ui_box_top "Next: the setup wizard"
  ui_box_row ""
  if [[ -n "$cmd" ]]; then
    ui_box_row "${C_DIM}Walk the first-login wizard the same way, changing nothing:$C_OFF"
  else
    ui_box_row "${C_DIM}$APP_ID is not installed here yet; once it is, walk the wizard the same way:$C_OFF"
  fi
  ui_box_row "  $C_PINK${cmd:-$APP_ID} onboarding --dry-run$C_OFF"
  ui_box_row ""
  ui_box_row "${C_DIM}After a real install and a reboot, the wizard opens by itself on the first login.$C_OFF"
  ui_box_row ""
  ui_box_bottom
  dry_banner "nothing was installed, written or changed"
  echo >&2
}

# run LABEL HINT CMD...: runs CMD with its output in the log, a spinner on a
# terminal, and on failure the log tail plus HINT. RUN_SOFT=1 turns the
# failure into a warning and a non-zero status instead of the end.
run() {
  local label="$1" hint="$2" rc=0 start
  shift 2
  start=$SECONDS
  if [[ "$DRY_RUN" == 1 ]]; then
    done_line "$label" "would run"
    dry_line "$@"
    return 0
  fi
  log "" "### $label: $*"
  if [[ "$VERBOSE" == 1 ]]; then
    printf '  %s%s%s %s\n' "$C_ROSE" "$G_STEP" "$C_OFF" "$label" >&2
    "$@" 2>&1 | tee -a "$LOG_FILE" || rc=$?
  elif [[ "$SPINNER" == 1 ]]; then
    "$@" >>"$LOG_FILE" 2>&1 </dev/null &
    local pid=$! i=0
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r  %s%s%s %s  %s%ss%s\033[K' "$C_PINK" "${G_SPIN:i++%10:1}" "$C_OFF" "$label" "$C_DIM" "$((SECONDS - start))" "$C_OFF" >&2
      sleep 0.1
    done
    wait "$pid" || rc=$?
    printf '\r\033[K' >&2
  else
    printf '  %s %s\n' "$G_LEAD" "$label" >&2
    "$@" >>"$LOG_FILE" 2>&1 </dev/null || rc=$?
  fi
  if [[ "$rc" -ne 0 ]]; then
    printf '  %s%s%s %s\n' "$C_RED" "$G_FAIL" "$C_OFF" "$label" >&2
    printf '%s' "$C_DIM" >&2
    # The error lines when there are any (download progress is noise).
    { grep -iE 'error|fail|conflict|not found|denied|cannot|unable' "$LOG_FILE" | tail -n 12 || tail -n 15 "$LOG_FILE"; } | sed "s/^/    $G_PIPE /" >&2
    printf '%s' "$C_OFF" >&2
    if [[ "${RUN_SOFT:-0}" == 1 ]]; then
      warn "$label failed (exit $rc); continuing.${hint:+ $hint}"
      return "$rc"
    fi
    die "$label failed (exit $rc)." "Full log: $LOG_FILE" ${hint:+"$hint"}
  fi
  done_line "$label" "$((SECONDS - start))s"
}

# run_optional NAME LABEL HINT CMD...: run, but a failure is only noted for
# the summary at the end (NAME: failed) and the install goes on.
run_optional() {
  local name="$1"
  shift
  RUN_SOFT=1 run "$@" || FAILED+=("$name")
  return 0
}

# run_attended LABEL HINT CMD...: CMD in the foreground on the terminal, for
# a command that asks its own questions (pacman without --noconfirm).
run_attended() {
  local label="$1" hint="$2" rc=0 start=$SECONDS
  shift 2
  [[ "$DRY_RUN" == 1 ]] && {
    run "$label" "$hint" "$@"
    return
  }
  log "" "### $label: $*"
  printf '  %s%s%s %s\n' "$C_ROSE" "$G_STEP" "$C_OFF" "$label" >&2
  "$@" <"$TTY" >&2 || rc=$?
  log "(attended, exit $rc)"
  [[ "$rc" -eq 0 ]] || die "$label failed (exit $rc)." "Full log: $LOG_FILE" ${hint:+"$hint"}
  done_line "$label" "$((SECONDS - start))s"
}

# retry CMD...: one more try after a pause (mirrors and COPR time out).
retry() {
  "$@" && return 0
  echo "--- failed, retrying in 10s ---"
  sleep 10
  "$@"
}

usage() {
  cat <<EOF
$DISPLAY_NAME installer

Usage: install.sh [options]
       curl -fsSL https://raw.githubusercontent.com/23iq/$APP_ID/main/install.sh | bash -s -- [options]

Installs the core: the shell, your compositor and a login screen. Asks which
compositor (Hyprland, niri or Mango), shows the plan (packages, services,
files) and asks once; at the end it offers a reboot into the setup wizard.
Without a terminal it proceeds with the defaults (Hyprland, no reboot).

Compositor:
  --compositor NAME hyprland (default), niri or mango (Mango: Arch only)
  --exclusive       Hyprland: let $DISPLAY_NAME manage the whole Hyprland config
  --no-compositor-config
                    leave the compositor's config files alone

Optional features (or later, from the setup wizard):
  --with-voice      local speech-to-text (builds whisper.cpp, ~1 GB)
  --with-depth      depth clock behind the wallpaper subject (uv venv, ~0.7 GB)
  --with-sddm       SDDM login screen + the $DISPLAY_NAME theme (default when
                    no display manager is installed)
  --no-voice, --no-depth, --no-sddm

Install:
  -y, --yes         do not ask; go with the plan
  --dry-run         walk the whole install (questions, plan, every step)
                    showing what would run; nothing is changed, no sudo
  --no-deps         skip packages and services (sources + binaries only)
  --no-aur          Arch: no AUR helper; the icon font is installed per user
  --reboot          reboot at the end without asking (needs a terminal)
  --no-reboot       do not offer the reboot at the end
  --update          update an existing install: pull, rebuild, reinstall the
                    binaries (what '$APP_ID update' runs)
  --verbose         show command output instead of spinners
  --dir PATH        source checkout       (default ~/.local/src/$APP_ID, env YOZAKURA_SRC)
  --bin-dir PATH    where binaries go     (default ~/.local/bin, env YOZAKURA_BIN_DIR)
  --branch NAME     git branch            (env YOZAKURA_BRANCH)
  -h, --help        this help

Environment: YOZAKURA_REPO_URL (git remote or path), YOZAKURA_RAW_BASE (where
the package list is fetched from), YOZAKURA_FLAKE (NixOS), YOZAKURA_GPU
(NVIDIA, AMD or Intel: overrides the graphics detection), YOZAKURA_OS_RELEASE
(an os-release file to read instead of /etc/os-release), YOZAKURA_SYS_BIN
(where the binaries are linked when needed, default /usr/local/bin).
Log: $LOG_FILE
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --with-voice) WITH_VOICE=1 ;;
    --with-depth) WITH_DEPTH=1 ;;
    --with-sddm) WITH_SDDM=1 ;;
    --no-voice) WITH_VOICE=0 ;;
    --no-depth) WITH_DEPTH=0 ;;
    --no-sddm) WITH_SDDM=0 ;;
    --no-deps) INSTALL_DEPS=0 ;;
    --no-aur) USE_AUR=0 ;;
    --no-compositor-config | --no-hyprland) COMP_CONFIG=0 ;;
    --exclusive) EXCLUSIVE=1 ;;
    --reboot) REBOOT=1 ;;
    --no-reboot) REBOOT=0 ;;
    --dry-run) DRY_RUN=1 ;;
    --verbose) VERBOSE=1 ;;
    --update) UPDATE_ONLY=1 INSTALL_DEPS=0 ASSUME_YES=1 COMP_CONFIG=0 REBOOT=0 ;;
    -y | --yes) ASSUME_YES=1 ;;
    --dir | --bin-dir | --branch | --compositor)
      [[ $# -ge 2 ]] || die "$1 needs a value"
      case "$1" in
      --compositor)
        COMPOSITOR="${2,,}"
        [[ " ${COMPOSITORS[*]} " == *" $COMPOSITOR "* ]] || die "Unknown compositor: $2" "Choose one of: ${COMPOSITORS[*]}"
        ;;
      --dir) SRC_DIR="$2" ;;
      --bin-dir) BIN_DIR="$2" ;;
      --branch)
        BRANCH="$2"
        [[ -n "${YOZAKURA_RAW_BASE:-}" ]] || RAW_BASE="https://raw.githubusercontent.com/23iq/yozakura/$BRANCH"
        ;;
      esac
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown option: $1" "See: install.sh --help" ;;
    esac
    shift
  done
  if [[ "$UPDATE_ONLY" == 1 ]]; then WITH_VOICE=0 WITH_DEPTH=0 WITH_SDDM=0; fi
}

# === Terminal and prompts ===
# The script is usually piped into bash (stdin is the script), so answers
# come from /dev/tty. Without a terminal every question takes its default.
detect_tty() {
  if (exec </dev/tty) 2>/dev/null && (exec >/dev/tty) 2>/dev/null; then TTY=/dev/tty; fi
}

# ask "question" y|n -> status 0 for yes
ask() {
  local question="$1" default="$2" hint reply
  if [[ -z "$TTY" || "$ASSUME_YES" == 1 ]]; then
    [[ "$default" == y ]]
    return
  fi
  [[ "$default" == y ]] && hint="Y/n" || hint="y/N"
  printf '  %s%s%s %s [%s] ' "$C_PINK" "$G_ASK" "$C_OFF" "$question" "$hint" >"$TTY"
  read -r reply <"$TTY" || reply=""
  [[ "${reply:-$default}" =~ ^[Yy] ]]
}

# === sudo ===
need_sudo() {
  [[ "$SUDO_OK" == 1 ]] && return 0
  if [[ "$DRY_RUN" == 1 ]]; then
    try_sudo
    return 0
  fi
  has_cmd sudo || die "sudo is not installed." "Install it as root (pacman -S sudo / dnf install sudo), or use --no-deps."
  [[ -n "$TTY" ]] || sudo -n true 2>/dev/null || die "sudo needs a password but there is no terminal." "Run 'sudo -v' first, or use --no-deps."
  SUDO_FAILED=0
  try_sudo || die "sudo authentication failed."
}

# try_sudo: need_sudo that reports instead of ending the install; a refused
# password is not asked for again.
try_sudo() {
  [[ "$SUDO_OK" == 1 ]] && return 0
  if [[ "$DRY_RUN" == 1 ]]; then
    has_cmd sudo || warn "sudo is not installed; the real install needs it here."
    info "sudo would ask for your password here (a dry run never asks)."
    SUDO_OK=1
    return 0
  fi
  [[ "$SUDO_FAILED" == 0 ]] && has_cmd sudo || return 1
  if ! sudo -n true 2>/dev/null; then
    if [[ -z "$TTY" ]]; then
      SUDO_FAILED=1
      return 1
    fi
    info "sudo may ask for your password."
    if ! sudo -v; then
      SUDO_FAILED=1
      return 1
    fi
  fi
  SUDO_OK=1
  # Keep the timestamp fresh for long package and build steps (the tests'
  # sandbox turns it off: its sudo is a stub).
  [[ -n "${YOZAKURA_NO_SUDO_KEEPALIVE:-}" ]] && return 0
  (while kill -0 "$$" 2>/dev/null; do
    sudo -n true 2>/dev/null
    sleep 50
  done) &
  KEEPALIVE_PID=$!
  trap '[[ -n "$KEEPALIVE_PID" ]] && kill "$KEEPALIVE_PID" 2>/dev/null' EXIT
}

# === System detection ===
detect_system() {
  local id="" name="" like=""
  if [[ -r "$OS_RELEASE" ]]; then
    # shellcheck disable=SC1090
    id="$(. "$OS_RELEASE" && echo "${ID:-}")" like="$(. "$OS_RELEASE" && echo "${ID_LIKE:-}")" name="$(. "$OS_RELEASE" && echo "${PRETTY_NAME:-}")"
  fi
  DISTRO_NAME="${name:-unknown}"
  if [[ -f /etc/NIXOS || "$id" == nixos ]]; then
    DISTRO=nixos
  elif has_cmd pacman || [[ " $id $like " == *" arch "* ]]; then
    DISTRO=arch
  elif has_cmd dnf || [[ " $id $like " == *" fedora "* ]]; then
    DISTRO=fedora
  else
    DISTRO=other
  fi

  local v vendors=()
  for v in /sys/class/drm/card*/device/vendor; do
    [[ -r "$v" ]] || continue
    case "$(cat "$v")" in
    0x10de) vendors+=(NVIDIA) ;;
    0x1002) vendors+=(AMD) ;;
    0x8086) vendors+=(Intel) ;;
    esac
  done
  GPU="$(printf '%s\n' "${vendors[@]:-}" | sort -u | paste -sd/ -)"
  GPU="${YOZAKURA_GPU:-${GPU:-unknown}}"

  DM=""
  if [[ -L /etc/systemd/system/display-manager.service ]]; then
    DM="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
  else
    for v in sddm gdm lightdm greetd ly; do
      if has_cmd "$v"; then
        DM="$v"
        break
      fi
    done
  fi
  return 0
}

has_systemd() { [[ -d /run/systemd/system ]]; }

# === Compositor ===
comp_name() {
  case "$1" in
  hyprland) echo Hyprland ;;
  mango) echo Mango ;;
  *) echo "$1" ;;
  esac
}

comp_about() {
  case "$1" in
  hyprland) echo "dynamic tiling with rich animations; the most tested with $DISPLAY_NAME" ;;
  niri) echo "scrollable tiling: windows open on an endless horizontal strip" ;;
  mango) echo "light, fast dwl-style tiling with many layouts" ;;
  esac
}

# comp_bin NAME: the compositor's executable (to tell whether it is there).
comp_bin() {
  case "$1" in
  hyprland) echo Hyprland ;;
  *) echo "$1" ;;
  esac
}

# comp_supported NAME: whether this distribution packages it (Mango: Arch only).
comp_supported() { [[ "$1" != mango || "$DISTRO" != fedora ]]; }

# comp_config NAME: the user config file '$APP_ID install NAME' adds its block to.
comp_config() {
  case "$1" in
  hyprland) echo "$HOME/.config/hypr/$(hypr_entry)" ;;
  niri) echo "$HOME/.config/niri/config.kdl" ;;
  mango) echo "$HOME/.config/mango/config.conf" ;;
  esac
}

# choose_compositor: COMPOSITOR = --compositor, else the configured one (a
# re-run never asks again), else the answer to a menu of the ones this
# distribution has (Hyprland without a terminal or with --yes).
choose_compositor() {
  local saved="$DATA_DIR/compositor" c="" opts=() i reply
  [[ -e "$saved" || -e "$DATA_DIR/shell_repo" ]] && PREV_INSTALL=1
  if [[ -n "$COMPOSITOR" ]]; then
    comp_supported "$COMPOSITOR" && return 0
    warn "$(comp_name "$COMPOSITOR") is not packaged for $DISTRO_NAME (Arch only)."
  elif [[ -r "$saved" ]]; then
    read -r c <"$saved" || true
    c="${c,,}"
    if [[ " ${COMPOSITORS[*]} " == *" $c "* ]] && comp_supported "$c"; then
      COMPOSITOR="$c"
      return 0
    fi
  fi
  for c in "${COMPOSITORS[@]}"; do comp_supported "$c" && opts+=("$c"); done
  if [[ -z "$TTY" || "$ASSUME_YES" == 1 || ${#opts[@]} -eq 1 ]]; then
    [[ -n "$COMPOSITOR" ]] && info "Using $(comp_name "${opts[0]}") instead."
    COMPOSITOR="${opts[0]}"
    return 0
  fi
  compositor_menu "${opts[@]}"
  while true; do
    printf '  %s%s%s Compositor [1-%d, Enter = 1] ' "$C_PINK" "$G_ASK" "$C_OFF" "${#opts[@]}" >"$TTY"
    read -r reply <"$TTY" || reply=""
    reply="${reply:-1}"
    if [[ "$reply" =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= ${#opts[@]})); then
      COMPOSITOR="${opts[reply - 1]}"
      break
    fi
    for i in "${!opts[@]}"; do
      [[ "${reply,,}" == "${opts[i]}" ]] && COMPOSITOR="${opts[i]}" && break 2
    done
  done
  ok "Compositor: $(comp_name "$COMPOSITOR")"
}

# compositor_menu NAME...: the numbered choices, a name and a line about each.
compositor_menu() {
  local i c tag about
  echo >&2
  ui_box_top "Choose your compositor"
  for ((i = 1; i <= $#; i++)); do
    c="${!i}" tag="" about="$(comp_about "$c")"
    ((i == 1)) && tag+="  ${C_PINK}recommended$C_OFF"
    has_cmd "$(comp_bin "$c")" && tag+="  ${C_GREEN}$G_OK installed$C_OFF"
    [[ "$c" == niri && "$DISTRO" == fedora ]] && about+=" (may need: sudo dnf copr enable yalter/niri)"
    ui_box_row ""
    ui_box_row "$(printf '%s%d%s  %s%s%s%s' "$C_PINK$C_BOLD" "$i" "$C_OFF" "$C_BOLD" "$(comp_name "$c")" "$C_OFF" "$tag")"
    ui_box_row "   $C_DIM$about$C_OFF"
  done
  comp_supported mango || { ui_box_row "" && ui_box_row "${C_DIM}Mango is not listed: it is packaged for Arch only.$C_OFF"; }
  ui_box_row ""
  ui_box_bottom
  echo >&2
}

# choose_login: offer SDDM only where there is no display manager.
choose_login() {
  [[ -z "$WITH_SDDM" ]] || return 0
  WITH_SDDM=0
  [[ -z "$DM" && "$INSTALL_DEPS" == 1 ]] && has_systemd || return 0
  if ask "No login screen found. Set up SDDM with the $DISPLAY_NAME theme?" y; then WITH_SDDM=1; fi
}

# === Package list (backend/pkg/deps/packages.tsv) ===
load_deps() {
  local local_tsv="$SRC_DIR/$DEPS_PATH"
  if DEPS_TSV="$(curl -fsSL "$RAW_BASE/$DEPS_PATH" 2>/dev/null)" && [[ -n "$DEPS_TSV" ]]; then
    return
  fi
  if [[ -r "$local_tsv" ]]; then
    DEPS_TSV="$(cat "$local_tsv")"
    return
  fi
  die "Could not fetch the package list from $RAW_BASE/$DEPS_PATH." "Check your connection, or set YOZAKURA_RAW_BASE."
}

# deps_for COLUMN: package names of every row whose need is wanted.
deps_for() {
  local col="$1" wanted="|build|required|standard|${COMPOSITOR:-hyprland}|"
  [[ "$WITH_VOICE" == 1 ]] && wanted+="voice|"
  [[ "$WITH_DEPTH" == 1 ]] && wanted+="depth|"
  [[ "$WITH_SDDM" == 1 ]] && wanted+="sddm|"
  awk -F'\t' -v col="$col" -v wanted="$wanted" '
    /^#/ || NF < 6 { next }
    index(wanted, "|" $2 "|") && $col != "-" { n = split($col, p, " "); for (i = 1; i <= n; i++) print p[i] }
  ' <<<"$DEPS_TSV"
}

# Packages that clash with common alternatives are skipped when the
# alternative is there, so pacman never stops at a "remove X?" question.
arch_skip() {
  case "$1" in
  quickshell) has_cmd qs ;;
  hyprland) has_cmd Hyprland ;;
  niri) has_cmd niri ;;
  mangowm) has_cmd mango ;;
  matugen) has_cmd matugen ;;
  power-profiles-daemon) pacman -Qq tlp tuned tuned-ppd auto-cpufreq >/dev/null 2>&1 ;;
  pipewire-pulse) pacman -Qq pulseaudio >/dev/null 2>&1 ;;
  *) return 1 ;;
  esac
}

plan_packages_arch() {
  local p all=() repo=() aur=()
  mapfile -t all < <(deps_for 4)
  for p in "${all[@]}"; do
    if [[ "$p" == aur:* ]]; then
      [[ "$USE_AUR" == 1 ]] && aur+=("${p#aur:}")
    elif ! arch_skip "$p"; then
      repo+=("$p")
    fi
  done
  # Without a JACK provider pacman would pick jack2; PipeWire's fits.
  [[ -n "$(pacman -T jack 2>/dev/null)" ]] && repo+=(pipewire-jack)
  mapfile -t PKGS < <(pacman -T "${repo[@]}" 2>/dev/null | sort -u || true)
  if [[ ${#aur[@]} -gt 0 ]]; then
    mapfile -t AUR_PKGS < <(pacman -T "${aur[@]}" 2>/dev/null || true)
    # The Phosphor font can also come from a user-level copy.
    if [[ " ${AUR_PKGS[*]} " == *" ttf-phosphor-icons "* ]] && has_phosphor; then
      AUR_PKGS=("${AUR_PKGS[@]/ttf-phosphor-icons/}")
      mapfile -t AUR_PKGS < <(printf '%s\n' "${AUR_PKGS[@]}" | grep . || true)
    fi
  fi
  if [[ ${#AUR_PKGS[@]} -gt 0 ]]; then
    if has_cmd paru; then
      AUR_HELPER=paru
    elif has_cmd yay; then
      AUR_HELPER=yay
    else
      AUR_HELPER="yay (bootstrapped from the AUR)"
      mapfile -t PKGS < <({
        printf '%s\n' "${PKGS[@]}"
        pacman -T base-devel git 2>/dev/null || true
      } | grep . | sort -u)
    fi
  fi
}

plan_packages_fedora() {
  local all=()
  mapfile -t all < <(deps_for 5)
  if has_cmd tlp || has_cmd tuned-adm; then
    mapfile -t all < <(printf '%s\n' "${all[@]}" | grep -vx power-profiles-daemon)
  fi
  # rpm prints "package X is not installed" for each missing one.
  mapfile -t PKGS < <(rpm -q "${all[@]}" 2>/dev/null | awk '/is not installed/ {print $2}' | sort -u || true)
}

plan_services() {
  SERVICES=()
  has_systemd || return 0
  local other=""
  for other in iwd systemd-networkd connman; do
    systemctl is-active --quiet "$other" 2>/dev/null && break
    other=""
  done
  [[ -z "$other" ]] && ! systemctl is-enabled --quiet NetworkManager 2>/dev/null && SERVICES+=(NetworkManager)
  systemctl is-enabled --quiet bluetooth 2>/dev/null || SERVICES+=(bluetooth)
  [[ "$WITH_SDDM" == 1 && -z "$DM" ]] && SERVICES+=(sddm)
  return 0
}

on_path() { case ":$PATH:" in *":$BIN_DIR:"* | *":${BIN_DIR%/}:"*) return 0 ;; esac; return 1; }

make_plan() {
  PKGS=() AUR_PKGS=() AUR_HELPER=""
  if [[ "$INSTALL_DEPS" == 1 ]]; then
    case "$DISTRO" in
    arch) plan_packages_arch ;;
    fedora) plan_packages_fedora ;;
    esac
    plan_services
    ADD_INPUT_GROUP=0
    # The group database, not this process: a fresh membership counts.
    [[ " $(id -nG "$(id -un)" 2>/dev/null) " == *" input "* ]] || ADD_INPUT_GROUP=1
  fi
  LINK_BINS=0
  if [[ "$BIN_DIR" != "$SYS_BIN" ]] && { ! on_path || [[ -e "$SYS_BIN/$APP_ID" ]]; }; then LINK_BINS=1; fi
  if [[ -d "$SRC_DIR/.git" || -f "$SRC_DIR/.git" ]]; then REPO_ACTION="update"; else REPO_ACTION="clone"; fi
}

feature_box() { [[ "$1" == 1 ]] && printf '%s%s%s' "$C_PINK" "$G_ON" "$C_OFF" || printf '%s%s%s' "$C_DIM" "$G_OFF" "$C_OFF"; }

# tilde PATH: PATH with $HOME shown as ~.
tilde() { [[ "$1" == "$HOME"* ]] && printf '~%s' "${1#"$HOME"}" || printf '%s' "$1"; }

# indented_list TEXT: TEXT folded, dim, under the value column of a box.
indented_list() {
  local line
  ui_box_width
  while IFS= read -r line; do
    ui_box_row "$(printf '%-12s %s%s%s' "" "$C_DIM" "$line" "$C_OFF")"
  done < <(fold -s -w $((UI_OUT - 4 - 13)) <<<"$1")
}

show_plan() {
  local s=" $G_SEP " old
  echo >&2
  ui_box_top "The plan"
  ui_box_head "THIS MACHINE"
  ui_box_kv "System" "$DISTRO_NAME$s$(uname -m)"
  ui_box_kv "Graphics" "$GPU"
  ui_box_kv "Login" "${DM:-none (console)}"
  ui_box_head "INSTALL"
  ui_box_kv "Compositor" "$C_BOLD$(comp_name "$COMPOSITOR")$C_OFF"
  ui_box_kv "Sources" "$REPO_ACTION $(tilde "$SRC_DIR")"
  ui_box_row "$(printf '%-12s %s%s%s' "" "$C_DIM" "$REPO_URL${BRANCH:+ @ $BRANCH}" "$C_OFF")"
  ui_box_kv "Binaries" "$(tilde "$BIN_DIR")/{$APP_ID,$DAEMON_ID}$([[ "$LINK_BINS" == 1 ]] && echo " + links in $SYS_BIN (sudo)")"
  old="$(old_daemon_paths | paste -sd' ' -)"
  ui_box_kv "Helper" "$SYS_HELPER (root-owned, sudo): the system helper for installing apps from the setup wizard"
  [[ -n "$old" ]] && ui_box_kv "Cleanup" "remove the old $OLD_DAEMON ($old) once $DAEMON_ID is installed"
  if [[ "$INSTALL_DEPS" == 1 ]]; then
    case "$DISTRO" in
    arch | fedora)
      local via="pacman -Syu"
      [[ "$DISTRO" == arch && "$ASSUME_YES" == 0 && -n "$TTY" ]] && via+=", which asks to confirm"
      [[ "$DISTRO" == fedora ]] && via="dnf, COPR $FEDORA_COPR"
      if [[ ${#PKGS[@]} -eq 0 ]]; then
        ui_box_kv "Packages" "all installed"
      else
        ui_box_kv "Packages" "$C_BOLD${#PKGS[@]}$C_OFF to install with $via (sudo)"
        indented_list "${PKGS[*]}"
      fi
      [[ ${#AUR_PKGS[@]} -gt 0 ]] && ui_box_kv "AUR" "${AUR_PKGS[*]} via $AUR_HELPER"
      [[ "$DISTRO" == fedora ]] && ui_box_kv "Fonts" "Phosphor icons into ~/.local/share/fonts"
      [[ "$DISTRO" == fedora && "$COMPOSITOR" == niri ]] &&
        ui_box_kv "Note" "if dnf cannot find niri or xwayland-satellite: sudo dnf copr enable yalter/niri, then re-run" "$C_YELLOW"
      ;;
    *) ui_box_kv "Packages" "no package list for this distribution; '$APP_ID doctor' lists what to install" "$C_YELLOW" ;;
    esac
    [[ ${#SERVICES[@]} -gt 0 ]] && ui_box_kv "Services" "enable ${SERVICES[*]}"
    [[ "$ADD_INPUT_GROUP" == 1 ]] && ui_box_kv "Groups" "add $(id -un) to 'input' (Super-alone binds)"
  fi
  if [[ "$COMP_CONFIG" == 1 ]]; then
    if [[ "$COMPOSITOR" == hyprland ]] && legacy_hypr_block; then
      ui_box_kv "Config" "your ${LEGACY_ID^} block in ~/.config/hypr is switched over on the first start"
    else
      ui_box_kv "Config" "add the $DISPLAY_NAME block to $(tilde "$(comp_config "$COMPOSITOR")")$([[ "$COMPOSITOR" == hyprland ]] && echo " (+ polkit agent autostart)")"
    fi
  fi
  if [[ "$EXCLUSIVE" == 1 ]]; then
    if [[ "$COMPOSITOR" == hyprland ]]; then
      ui_box_kv "Exclusive" "$DISPLAY_NAME manages the whole Hyprland config ('$APP_ID install hyprland --exclusive')"
    else
      ui_box_kv "Exclusive" "only for Hyprland; ignored for $(comp_name "$COMPOSITOR")" "$C_YELLOW"
    fi
  fi
  ui_box_head "OPTIONAL"
  ui_box_kv "Features" "$(feature_box "$WITH_VOICE") voice   $(feature_box "$WITH_DEPTH") depth clock   $(feature_box "$WITH_SDDM") SDDM theme"
  [[ "$WITH_VOICE" == 1 ]] && ui_box_kv "Voice" "whisper.cpp, $(voice_backend) build"
  ui_box_kv "Later" "apps, fonts and the rest from the setup wizard on the first login"
  [[ "$GPU" == *NVIDIA* ]] && ui_box_kv "Note" "NVIDIA: Wayland compositors need the proprietary driver set up (nvidia-open + kernel modeset)" "$C_YELLOW"
  ui_box_row ""
  if [[ "$DRY_RUN" == 1 ]]; then
    ui_box_kv "Dry run" "every step is shown, nothing runs; no log is written" "$C_YELLOW"
  else
    ui_box_kv "Log" "$C_DIM$(tilde "$LOG_FILE")$C_OFF"
  fi
  ui_box_bottom
  echo >&2
}

confirm_plan() {
  [[ "$ASSUME_YES" == 1 || -z "$TTY" ]] && return 0
  local reply
  printf '  %s%s%s Proceed? [Y/n] ' "$C_PINK" "$G_ASK" "$C_OFF" >"$TTY"
  read -r reply <"$TTY" || reply=n
  [[ "${reply:-y}" =~ ^[Yy] ]] && return 0
  info "Nothing was changed."
  exit 0
}

# === Steps ===
install_packages() {
  case "$DISTRO" in
  arch)
    # A full upgrade is confirmed by the person unless they said --yes;
    # without a terminal nobody could answer, so that run is a --yes one.
    if [[ ${#PKGS[@]} -gt 0 && "$ASSUME_YES" == 0 && -n "$TTY" ]]; then
      run_attended "Installing ${#PKGS[@]} packages (pacman)" "Fix the pacman error above, then re-run the installer." \
        sudo pacman -Syu --needed "${PKGS[@]}"
    elif [[ ${#PKGS[@]} -gt 0 ]]; then
      run "Installing ${#PKGS[@]} packages (pacman)" "Fix the pacman error above, then re-run the installer." \
        retry sudo pacman -Syu --needed --noconfirm "${PKGS[@]}"
    fi
    if [[ ${#AUR_PKGS[@]} -gt 0 ]]; then
      if [[ "$AUR_HELPER" == yay* ]] && ! has_cmd yay; then
        run "Bootstrapping yay (AUR helper)" "Re-run with --no-aur to skip the AUR." bootstrap_yay
      fi
      local helper=paru
      has_cmd paru || helper=yay
      run "Installing from the AUR: ${AUR_PKGS[*]}" "Re-run with --no-aur to skip the AUR." \
        retry "$helper" -S --needed --noconfirm "${AUR_PKGS[@]}"
    fi
    ;;
  fedora)
    run "Enabling COPR $FEDORA_COPR" "" retry sudo dnf copr enable -y "$FEDORA_COPR"
    if [[ ${#PKGS[@]} -gt 0 ]]; then
      local skip=--skip-unavailable
      [[ "$(dnf --version 2>/dev/null)" == dnf5* ]] || skip=--setopt=strict=0
      run "Installing ${#PKGS[@]} packages (dnf)" "Fix the dnf error above, then re-run the installer." \
        retry sudo dnf install -y "$skip" --setopt=install_weak_deps=False "${PKGS[@]}"
    fi
    ;;
  esac
}

bootstrap_yay() {
  local dir
  dir="$(mktemp -d)"
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$dir" &&
    (cd "$dir" && makepkg -si --noconfirm)
  local rc=$?
  rm -rf "$dir"
  return $rc
}

# Phosphor icon font: no package on Fedora (and no AUR with --no-aur), so it
# goes to the user's font dir.
install_phosphor() {
  has_phosphor && return 0
  run_optional "icon font" "Installing the Phosphor icon font (per user)" "Icons stay blank without it; re-run the installer later." phosphor_user_font
}

phosphor_user_font() {
  local tmp font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/phosphor"
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/phosphor-icons/web/archive/refs/tags/v${PHOSPHOR_VERSION}.zip" -o "$tmp/phosphor.zip" &&
    unzip -q "$tmp/phosphor.zip" -d "$tmp" &&
    mkdir -p "$font_dir" &&
    find "$tmp" -name "Phosphor*.ttf" -exec cp {} "$font_dir/" \; &&
    { ! has_cmd fc-cache || fc-cache -f "$font_dir"; }
  local rc=$?
  rm -rf "$tmp"
  return $rc
}

configure_system() {
  local svc
  for svc in "${SERVICES[@]}"; do
    if [[ "$svc" == sddm ]]; then
      # Starting a display manager now would take over the screen mid-install.
      run "Enabling sddm (from the next boot)" "Enable it later: sudo systemctl enable sddm" sudo systemctl enable sddm
    else
      run "Enabling $svc" "Enable it later: sudo systemctl enable --now $svc" sudo systemctl enable --now "$svc"
    fi
  done
  if [[ "$ADD_INPUT_GROUP" == 1 ]]; then
    run "Adding $(id -un) to the 'input' group" "" add_input_group
  fi
  if [[ ${#SERVICES[@]} -eq 0 ]] && ! has_systemd; then
    info "systemd is not running here; services were left alone."
  fi
}

add_input_group() {
  getent group input >/dev/null || sudo groupadd --system input
  sudo usermod -aG input "$(id -un)"
}

# Only called when $SRC_DIR did not exist, so a partial clone can go.
clone_repo() {
  rm -rf "$SRC_DIR"
  git clone ${BRANCH:+--branch "$BRANCH"} "$REPO_URL" "$SRC_DIR"
}

sync_repo() {
  if [[ ! -e "$SRC_DIR" ]]; then
    would mkdir -p "$(dirname "$SRC_DIR")"
    run "Cloning the sources" "Check the URL and your connection." retry clone_repo
    return
  fi
  [[ -d "$SRC_DIR/.git" || -f "$SRC_DIR/.git" ]] || die "$SRC_DIR exists but is not a git checkout." "Move it away or pass --dir."
  run "Fetching updates" "Check your connection." git -C "$SRC_DIR" fetch --quiet origin ${BRANCH:+"$BRANCH"}
  if [[ "$DRY_RUN" == 1 ]]; then
    [[ -n "$BRANCH" ]] && dry_line git -C "$SRC_DIR" checkout -q "$BRANCH"
    dry_note run "git -C $(printf '%q' "$SRC_DIR") merge --ff-only origin/<branch> (kept as it is with local changes)"
    return
  fi
  if [[ -n "$BRANCH" && "$(git -C "$SRC_DIR" rev-parse --abbrev-ref HEAD)" != "$BRANCH" ]]; then
    git -C "$SRC_DIR" checkout -q "$BRANCH" 2>/dev/null || git -C "$SRC_DIR" checkout -q -b "$BRANCH" --track "origin/$BRANCH" ||
      die "Could not switch $SRC_DIR to $BRANCH."
  fi
  local branch upstream
  branch="$(git -C "$SRC_DIR" rev-parse --abbrev-ref HEAD)"
  upstream="origin/$branch"
  if [[ "$branch" == HEAD ]] || ! git -C "$SRC_DIR" rev-parse --verify --quiet "$upstream" >/dev/null; then
    warn "$SRC_DIR is not on a tracking branch; building it as it is."
    return
  fi
  if [[ -n "$(git -C "$SRC_DIR" status --porcelain --untracked-files=no)" ]] ||
    [[ -n "$(git -C "$SRC_DIR" log --oneline "$upstream..HEAD")" ]]; then
    warn "$SRC_DIR has local changes; they are kept and built as they are."
    info "To take the upstream version: git -C $SRC_DIR reset --hard $upstream"
    return
  fi
  if git -C "$SRC_DIR" merge --ff-only --quiet "$upstream" 2>>"$LOG_FILE"; then
    ok "Sources at $(git -C "$SRC_DIR" rev-parse --short HEAD) ($upstream)"
  else
    warn "Could not fast-forward to $upstream; building the current tree."
  fi
}

build_backend() {
  if ! has_cmd go || ! has_cmd make; then
    # Prebuilt binaries are the fallback: they match the sources only when
    # the checkout is at the release they were built from.
    warn "Go/make are missing; trying the prebuilt release binaries instead."
    run "Downloading release binaries" "Install go and make (or drop --no-deps) to build from source." download_release
    return
  fi
  run "Building $APP_ID and $DAEMON_ID ($(go version | awk '{print $3}'))" "Report the build error above as an issue." make -C "$SRC_DIR" build
  if [[ "$DRY_RUN" == 0 && -d "$SRC_DIR/backend/cmd/$DAEMON_ID" && ! -x "$SRC_DIR/$DAEMON_ID" ]]; then
    run "Building $DAEMON_ID" "" bash -c "cd '$SRC_DIR/backend' && go build -o '../$DAEMON_ID' './cmd/$DAEMON_ID'"
  fi
}

# Latest release assets <bin>-linux-<arch>, checked against SHA256SUMS, into
# the checkout (where a build would have put them).
download_release() {
  local arch base b
  case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *)
    echo "no prebuilt binaries for $(uname -m)"
    return 1
    ;;
  esac
  base="${REPO_URL%.git}/releases/latest/download"
  curl -fsSL "$base/SHA256SUMS" -o "$SRC_DIR/.SHA256SUMS" || return 1
  for b in "$APP_ID" "$DAEMON_ID"; do
    curl -fsSL "$base/$b-linux-$arch" -o "$SRC_DIR/$b-linux-$arch" || return 1
  done
  (cd "$SRC_DIR" && grep -E " ($APP_ID|$DAEMON_ID)-linux-$arch\$" .SHA256SUMS | sha256sum --check --strict) || return 1
  for b in "$APP_ID" "$DAEMON_ID"; do
    mv -f "$SRC_DIR/$b-linux-$arch" "$SRC_DIR/$b" && chmod 755 "$SRC_DIR/$b"
  done
  rm -f "$SRC_DIR/.SHA256SUMS"
}

installed_bins() {
  local b
  for b in "$APP_ID" "$DAEMON_ID"; do [[ -x "$SRC_DIR/$b" ]] && echo "$b"; done
  return 0
}

install_binaries() {
  local b built target bins=("$APP_ID" "$DAEMON_ID")
  # A dry run built nothing: it shows the steps for both binaries.
  [[ "$DRY_RUN" == 1 ]] || mapfile -t bins < <(installed_bins)
  [[ ${#bins[@]} -gt 0 ]] || die "The build produced no binaries in $SRC_DIR."
  if [[ "$DRY_RUN" == 0 ]]; then
    mkdir -p "$BIN_DIR" 2>/dev/null || true
  elif [[ ! -d "$BIN_DIR" ]]; then
    dry_line mkdir -p "$BIN_DIR"
  fi
  for b in "${bins[@]}"; do
    built="$SRC_DIR/$b" target="$BIN_DIR/$b"
    if [[ -e "$target" && "$(readlink -f "$target")" == "$(readlink -f "$built")" ]]; then
      continue
    elif [[ -w "$BIN_DIR" || ("$DRY_RUN" == 1 && ! -e "$BIN_DIR") ]]; then
      would install -m 755 "$built" "$target.new" && would mv -f "$target.new" "$target"
    else
      need_sudo
      would sudo install -D -m 755 "$built" "$target"
    fi
  done
  done_or_would "Installed ${bins[*]} to $BIN_DIR" "install ${bins[*]} to $BIN_DIR"
  # Tell the binary where its QML sources are (see backend/pkg/paths).
  write_file "$DATA_DIR/shell_repo" "$SRC_DIR"$'\n'
  if [[ "$LINK_BINS" == 1 ]]; then
    need_sudo
    for b in "${bins[@]}"; do would sudo ln -sf "$BIN_DIR/$b" "$SYS_BIN/$b"; done
    done_or_would "Linked them into $SYS_BIN (the compositor's autostart uses the session PATH)" \
      "link them into $SYS_BIN (the compositor's autostart uses the session PATH)"
  fi
  logged "$BIN_DIR/$APP_ID" version || die "The installed $APP_ID does not run." "See $LOG_FILE"
}

# The setup wizard installs apps through pkexec and $SYS_HELPER: a
# root-owned copy, so code running as the user cannot swap what runs as root.
# helper_stale: the helper is missing or differs from the installed binary
# (asked before the build too, so sudo is requested up front).
helper_stale() { [[ ! -x "$SYS_HELPER" ]] || ! cmp -s "$BIN_DIR/$APP_ID" "$SYS_HELPER"; }

# helper_sudo: sudo up front for the helper, with the other gates, so no
# password prompt waits after the build. A refusal is only a warning.
helper_sudo() {
  helper_stale || return 0
  try_sudo || warn "Without sudo the system helper for the setup wizard's app installs is skipped."
  return 0
}

install_sys_helper() {
  local bin="$BIN_DIR/$APP_ID" fix
  [[ -x "$bin" || "$DRY_RUN" == 1 ]] || return 0
  helper_stale || return 0
  fix="sudo install -D -o root -g root -m 0755 $bin $SYS_HELPER"
  if ! try_sudo; then
    warn "sudo cannot run here; the setup wizard cannot install apps until: $fix"
    FAILED+=("system helper")
    return 0
  fi
  run_optional "system helper" "System helper for installing apps from the setup wizard (root-owned copy)" "Retry later: $fix" \
    sudo install -D -o root -g root -m 0755 "$bin" "$SYS_HELPER"
}

# Previous Ambxst installs left Axenide's axctl next to it; yozd replaces it.
# Removed only once yozd is installed, and only a binary that identifies
# itself as axctl (its --version, or the Go build info).
OLD_DAEMON="axctl"
old_daemon_paths() {
  local p v
  for p in "$SYS_BIN/$OLD_DAEMON" "$HOME/.local/bin/$OLD_DAEMON"; do
    [[ -f "$p" ]] || continue
    # A dry run runs nothing foreign: only the Go build info is read.
    v="$(go version -m "$p" 2>/dev/null || true)"
    [[ "$DRY_RUN" == 1 ]] || v+=" $("$p" --version 2>&1 || true)"
    [[ "${v,,}" == *"$OLD_DAEMON"* ]] && echo "$p"
  done
  return 0
}

remove_old_daemon() {
  [[ -x "$BIN_DIR/$DAEMON_ID" || "$DRY_RUN" == 1 ]] || return 0
  local p
  while read -r p; do
    [[ -n "$p" ]] || continue
    if [[ -w "$(dirname "$p")" ]]; then
      would rm -f "$p"
    else
      need_sudo
      would sudo rm -f "$p"
    fi
    done_or_would "Removed the old $OLD_DAEMON ($p); $DAEMON_ID replaces it" "remove the old $OLD_DAEMON ($p); $DAEMON_ID replaces it"
  done < <(old_daemon_paths)
}

# === Compositor setup ===
legacy_hypr_block() {
  grep -qs "/.local/share/$LEGACY_ID/" "$HOME/.config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.conf"
}

# The choice is recorded for '$APP_ID doctor' and the shell, then the
# compositor's config gets the $DISPLAY_NAME block.
compositor_setup() {
  local name
  name="$(comp_name "$COMPOSITOR")"
  write_file "$DATA_DIR/compositor" "$COMPOSITOR"$'\n'
  [[ "$COMP_CONFIG" == 1 ]] || return 0
  # A config that still loads the legacy shell is switched by the binary's
  # first start, once the new generated config exists (backend/pkg/migrate).
  if [[ "$COMPOSITOR" == hyprland ]] && legacy_hypr_block; then
    info "Your Hyprland config loads ${LEGACY_ID^}; the first start of '$APP_ID' switches it over (.pre-$APP_ID backups)."
    LEGACY_PENDING=1
    return 0
  fi
  logged "$BIN_DIR/$APP_ID" install "$COMPOSITOR" || die "'$APP_ID install $COMPOSITOR' failed." "See $LOG_FILE"
  if [[ "$COMPOSITOR" == hyprland ]]; then
    hyprland_bootstrap
    run_optional "polkit autostart" "Polkit agent autostart" "Start a polkit agent from your Hyprland config yourself." polkit_autostart
  fi
  done_or_would "$name config: $(tilde "$(comp_config "$COMPOSITOR")")" "add the $DISPLAY_NAME block to the $name config: $(tilde "$(comp_config "$COMPOSITOR")")"
}

# --exclusive: $DISPLAY_NAME takes over the whole Hyprland config. Older
# binaries do not know the flag; then it is skipped with a note.
exclusive_setup() {
  [[ "$EXCLUSIVE" == 1 && "$COMP_CONFIG" == 1 ]] || return 0
  if [[ "$LEGACY_PENDING" == 1 ]]; then
    warn "--exclusive skipped: the ${LEGACY_ID^} block is switched over first; re-run '$APP_ID install hyprland --exclusive' after the first start."
    return 0
  fi
  if [[ "$COMPOSITOR" != hyprland ]]; then
    warn "--exclusive is for Hyprland only; skipped for $(comp_name "$COMPOSITOR")."
    return 0
  fi
  local help=exclusive
  # A dry run has no new binary to ask; the one it would build knows it.
  [[ "$DRY_RUN" == 1 ]] || help="$("$BIN_DIR/$APP_ID" install --help 2>&1 || true)"
  if [[ "$help" != *exclusive* ]]; then
    warn "This $APP_ID build cannot manage the whole Hyprland config yet; --exclusive skipped."
    return 0
  fi
  run_optional "exclusive" "Handing the Hyprland config to $DISPLAY_NAME" "Retry later: $APP_ID install hyprland --exclusive" \
    "$BIN_DIR/$APP_ID" install hyprland --exclusive
}

hypr_entry() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  if [[ -f "$dir/hyprland.lua" || ! -f "$dir/hyprland.conf" ]]; then echo hyprland.lua; else echo hyprland.conf; fi
}

# The block loads <data dir>/hyprland.{lua,conf}, which the shell generates
# on its first start. Until then a stub that only starts the shell (absolute
# path) keeps the first login error-free and brings the shell up.
hyprland_bootstrap() {
  local bin="$BIN_DIR/$APP_ID" note="Bootstrap written by the $DISPLAY_NAME installer; replaced on the first start." text
  if [[ ! -e "$DATA_DIR/hyprland.lua" ]]; then
    printf -v text -- '-- %s\nhl.on("hyprland.start", function()\n    hl.exec_cmd("%s")\nend)\n' "$note" "$bin"
    write_file "$DATA_DIR/hyprland.lua" "$text"
  fi
  if [[ ! -e "$DATA_DIR/hyprland.conf" ]]; then
    printf -v text '# %s\nexec-once = %s\n' "$note" "$bin"
    write_file "$DATA_DIR/hyprland.conf" "$text"
  fi
  return 0
}

# hyprpolkitagent ships a user unit but plain Hyprland sessions never reach
# graphical-session.target, so it is started from the user's config (once,
# only when no polkit agent is configured there yet).
# The line ends in "<comment> $APP_ID: polkit" so '$APP_ID goodbye' removes
# exactly that line.
polkit_autostart() {
  local entry marker="$APP_ID: polkit"
  entry="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/$(hypr_entry)"
  [[ -e /usr/lib/systemd/user/hyprpolkitagent.service ]] || return 0
  grep -qsi polkit "$entry" && return 0
  if [[ "$entry" == *.lua ]]; then
    printf '\nhl.on("hyprland.start", function() hl.exec_cmd("systemctl --user start hyprpolkitagent") end) -- %s\n' "$marker" >>"$entry"
  else
    printf '\nexec-once = systemctl --user start hyprpolkitagent # %s\n' "$marker" >>"$entry"
  fi
}

legacy_notes() {
  local legacy_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/$LEGACY_ID"
  [[ -d "$legacy_cfg" ]] || has_cmd "$LEGACY_ID" || return 0
  info "${LEGACY_ID^} found: its settings, presets and data are copied (never moved) on the first start."
  if pgrep -x "$LEGACY_ID" >/dev/null 2>&1; then
    warn "${LEGACY_ID^} is running: quit it ('$LEGACY_ID quit') before starting $DISPLAY_NAME."
  fi
  return 0
}

# CUDA_PATH (set by the cuda package's profile) narrows the search to it.
has_nvcc() {
  local d
  has_cmd nvcc && return 0
  for d in ${CUDA_PATH:-/opt/cuda /usr/local/cuda}; do [[ -x "$d/bin/nvcc" ]] && return 0; done
  return 1
}

# voice_backend: the whisper.cpp build for this GPU. CUDA (the script's own
# default) needs NVIDIA plus the toolkit, Vulkan an AMD or Intel GPU and a
# voice_setup.sh that knows --vulkan; everything else builds for the CPU.
voice_backend() {
  local gpu="${GPU,,}"
  if [[ "$gpu" == *nvidia* ]] && has_nvcc; then
    echo cuda
  elif [[ "$gpu" == *amd* || "$gpu" == *intel* ]] && grep -qs -- '--vulkan)' "$SRC_DIR/scripts/voice_setup.sh"; then
    echo vulkan
  else
    echo cpu
  fi
}

optional_features() {
  local scripts="$SRC_DIR/scripts" voice=() depth=()
  if [[ "$WITH_DEPTH" == 1 ]]; then
    # NVIDIA: onnxruntime with pip-packaged CUDA (only the driver needed).
    [[ "${GPU,,}" == *nvidia* ]] && depth=(--gpu)
    run_optional "depth" "Depth clock (venv + model)" "Retry later: $scripts/depth_setup.sh ${depth[*]}" bash "$scripts/depth_setup.sh" "${depth[@]}"
  fi
  if [[ "$WITH_VOICE" == 1 ]]; then
    case "$(voice_backend)" in
    vulkan) voice=(--vulkan) ;;
    cpu) voice=(--cpu) ;;
    esac
    run_optional "voice" "Voice input (building whisper.cpp, downloading the model)" "Retry later: $scripts/voice_setup.sh ${voice[*]}" bash "$scripts/voice_setup.sh" "${voice[@]}"
  fi
  if [[ "$WITH_SDDM" == 1 ]]; then
    # A dry run installed no packages; the real one would have added sddm.
    if has_cmd sddm || [[ "$DRY_RUN" == 1 ]]; then
      need_sudo
      run_optional "sddm theme" "SDDM theme" "Retry later: sudo $scripts/install-sddm-theme.sh \$USER" sudo bash "$scripts/install-sddm-theme.sh" "$(id -un)"
    else
      warn "SDDM is not installed; skipped the login theme."
      FAILED+=("sddm theme")
    fi
  fi
  return 0
}

run_doctor() {
  step "Checking the result"
  local args=() features=()
  [[ "$WITH_VOICE" == 1 ]] && features+=(voice)
  [[ "$WITH_DEPTH" == 1 ]] && features+=(depth)
  [[ "$WITH_SDDM" == 1 ]] && features+=(sddm)
  [[ ${#features[@]} -gt 0 ]] && args=(--with "$(
    IFS=,
    echo "${features[*]}"
  )")
  if [[ "$DRY_RUN" == 1 ]]; then
    dry_line "$BIN_DIR/$APP_ID" doctor "${args[@]}"
    return 0
  fi
  "$BIN_DIR/$APP_ID" doctor "${args[@]}" 2>&1 | sed 's/^/  /' >&2 || true
}

# done_header: the blossom beside "Yozakura <version> is installed".
done_header() {
  local ver i rows flower right=() name line art=("${ART_FLOWER[@]}")
  ver="$(head -n1 "$SRC_DIR/version" 2>/dev/null || true)"
  line="$DISPLAY_NAME ${ver:+$ver }is installed"
  [[ "$DRY_RUN" == 1 ]] && line="$DISPLAY_NAME ${ver:+$ver }would be installed"
  echo >&2
  if [[ "$UI_UTF8" == 0 ]]; then
    printf '  %s%s %s%s\n\n' "$C_PINK$C_BOLD" "$G_STEP" "$line" "$C_OFF" >&2
    return
  fi
  ((UI_COLS < 80)) && art=("${ART_FLOWER_SMALL[@]}")
  rows=${#art[@]}
  ui_paint "$DISPLAY_NAME" 0 0 "${#DISPLAY_NAME}" 1 && name="$C_BOLD$UI_OUT"
  right[rows / 2 - 2]="$name ${C_BOLD}${line#"$DISPLAY_NAME "}$C_OFF"
  art_brush "${#line}" && right[rows / 2 - 1]="$UI_OUT"
  ui_paint "$ART_KANJI" 0 0 4 1 && right[rows / 2 + 1]="$C_BOLD$UI_OUT  ${C_DIM}the blossoms are out$C_OFF"
  for ((i = 0; i < rows; i++)); do
    ui_paint "${art[i]}" 0 "$i" "${#art[0]}" "$rows" && flower="$UI_OUT"
    printf '  %s   %s\n' "$flower" "${right[i]:-}" >&2
  done
  echo >&2
}

# numbered N TEXT: one line of the next steps.
numbered() { ui_box_row "$(printf '%s%s%s  %s' "$C_PINK$C_BOLD" "$1" "$C_OFF" "$2")"; }
command_row() { ui_box_row "$(printf '%s%-18s%s %s%s%s' "$C_PINK" "$1" "$C_OFF" "$C_DIM" "$2" "$C_OFF")"; }

# in_session: whether this terminal runs inside the chosen compositor.
in_session() {
  case "$COMPOSITOR" in
  hyprland) [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] ;;
  niri) [[ -n "${NIRI_SOCKET:-}" ]] ;;
  *)
    local desktop="${XDG_CURRENT_DESKTOP:-}"
    [[ "${desktop,,}" == *"$COMPOSITOR"* ]]
    ;;
  esac
}

# console_cmd: how to start the compositor from a text console.
console_cmd() {
  case "$COMPOSITOR" in
  hyprland) echo "start-hyprland" ;;
  niri) echo "niri-session" ;;
  *) echo "mango" ;;
  esac
}

next_steps() {
  local name f
  name="${C_PINK}$(comp_name "$COMPOSITOR")${C_OFF}"
  done_header
  ui_box_top "Next steps"
  ui_box_row ""
  if in_session; then
    numbered 1 "You are in $name already: run $C_PINK$APP_ID$C_OFF now."
    numbered 2 "From the next login on it starts with $name."
  elif [[ " ${SERVICES[*]} " == *" sddm "* ]]; then
    numbered 1 "Reboot and pick $name on the new login screen."
    numbered 2 "The setup wizard greets you there. Super opens the launcher."
  elif [[ -n "$DM" || "$WITH_SDDM" == 1 ]]; then
    numbered 1 "Log out (or reboot) and pick $name on the login screen."
    numbered 2 "The setup wizard greets you there. Super opens the launcher."
  else
    numbered 1 "Log in on a console and run ${C_PINK}$(console_cmd)${C_OFF}."
    numbered 2 "The setup wizard greets you there. Super opens the launcher."
  fi
  [[ "$ADD_INPUT_GROUP" == 1 ]] && numbered "$G_INFO" "Log in again for the input group (Super-alone binds)."
  if [[ ${#FAILED[@]} -gt 0 ]]; then
    ui_box_head "NEEDS ATTENTION"
    for f in "${FAILED[@]}"; do
      ui_box_row "$C_YELLOW$G_WARN$C_OFF $f: failed (see log)"
    done
  fi
  ui_box_head "COMMANDS"
  command_row "$APP_ID doctor" "check the install"
  command_row "$APP_ID update" "pull, rebuild and reinstall"
  command_row "$APP_ID goodbye" "uninstall"
  ui_box_head "LATER"
  command_row "apps, voice, more" "the setup wizard ($APP_ID onboarding)"
  [[ "$DRY_RUN" == 1 ]] || command_row "install log" "$(tilde "$LOG_FILE")"
  ui_box_row ""
  ui_box_bottom
  echo >&2
}

# offer_reboot: the first login after a reboot lands in the setup wizard.
# Asked only on a first install with a terminal; --yes means no (unless
# --reboot), and the default is yes when this run set up the login screen.
offer_reboot() {
  local default=n
  [[ "$REBOOT" == 0 || -z "$TTY" ]] && return 0
  if [[ "$REBOOT" != 1 ]]; then
    [[ "$PREV_INSTALL" == 1 || "$ASSUME_YES" == 1 ]] && return 0
    in_session && return 0
    [[ " ${SERVICES[*]} " == *" sddm "* ]] && default=y
    ask "Reboot now to start $DISPLAY_NAME?" "$default" || return 0
  fi
  [[ "$DRY_RUN" == 1 ]] || info "Rebooting..."
  would systemctl reboot || warn "Could not reboot; reboot yourself to start $DISPLAY_NAME."
}

finish() {
  run_doctor
  next_steps
  offer_reboot
  dry_end
}

# === NixOS ===
nixos_flow() {
  show_nixos_plan() {
    echo >&2
    ui_box_top "The plan"
    ui_box_row ""
    ui_box_kv "NixOS" "add $FLAKE_URI to your nix profile (every dependency is in the flake package)"
    ui_box_head "SYSTEM-WIDE"
    ui_box_row "${C_DIM}For Hyprland itself, portals and the login session, use the NixOS module:$C_OFF"
    ui_box_row "  inputs.$APP_ID.url = \"$FLAKE_URI\";"
    ui_box_row "  ${C_DIM}# in your nixosSystem modules (enables Hyprland, portals, polkit, pipewire):$C_OFF"
    ui_box_row "  $APP_ID.nixosModules.default"
    ui_box_row ""
    ui_box_bottom
    echo >&2
  }
  show_nixos_plan
  confirm_plan
  local name
  # The entry name comes from the flake URL; find it by its store path.
  name="$(nix profile list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' |
    awk -v id="$APP_ID-" '/^Name:/ {n = $2} /^Store paths:/ && tolower($0) ~ id {print n; exit}')"
  if [[ -n "$name" ]]; then
    run "Updating the nix profile entry '$name'" "" nix profile upgrade "$name" --refresh --impure
  else
    run "Adding $FLAKE_URI to your nix profile" "" bash -c "nix profile add '$FLAKE_URI' --impure || nix profile install '$FLAKE_URI' --impure"
  fi
  printf '\n  Next: %s install hyprland, then log into Hyprland (programs.hyprland.enable = true).\n\n' "$APP_ID" >&2
  dry_end
}

main() {
  parse_args "$@"
  [[ "$EUID" -eq 0 ]] && die "Run this as your user, not root." "It uses sudo for the steps that need it."
  if [[ "$DRY_RUN" == 0 ]]; then
    mkdir -p "$LOG_DIR"
    printf '# %s installer, %s\n' "$DISPLAY_NAME" "$(date)" >"$LOG_FILE"
  fi
  detect_tty
  detect_system

  if [[ "$UPDATE_ONLY" == 1 ]]; then
    [[ "$DRY_RUN" == 1 ]] && dry_banner "an update walk-through: commands are shown, nothing runs"
    step "Updating $DISPLAY_NAME"
    LINK_BINS=0
    [[ "$BIN_DIR" != "$SYS_BIN" && -e "$SYS_BIN/$APP_ID" && "$(readlink -f "$SYS_BIN/$APP_ID")" != "$(readlink -f "$BIN_DIR/$APP_ID")" ]] && LINK_BINS=1
    helper_sudo
    sync_repo
    build_backend
    install_binaries
    install_sys_helper
    remove_old_daemon
    done_or_would "Updated. Run '$APP_ID reload' to restart the shell." "be updated; then '$APP_ID reload' restarts the shell"
    dry_end
    return
  fi

  banner
  [[ "$DRY_RUN" == 1 ]] && dry_banner "a walk-through: each step shows what it would run; nothing is changed"
  if [[ "$DISTRO" == nixos ]]; then
    nixos_flow
    return
  fi

  # The only questions before the plan: the compositor, and SDDM when
  # there is no login manager on a real (systemd) system.
  choose_compositor
  choose_login
  WITH_VOICE="${WITH_VOICE:-0}" WITH_DEPTH="${WITH_DEPTH:-0}"
  [[ "$INSTALL_DEPS" == 1 ]] && load_deps
  make_plan
  show_plan
  confirm_plan

  if [[ "$INSTALL_DEPS" == 1 ]]; then
    step "Packages"
    [[ ${#PKGS[@]} -gt 0 || ${#AUR_PKGS[@]} -gt 0 || "$DISTRO" == fedora ]] && need_sudo
    install_packages
    install_phosphor
    if [[ ${#SERVICES[@]} -gt 0 || "$ADD_INPUT_GROUP" == 1 ]]; then
      step "System"
      need_sudo
      configure_system
    fi
  fi
  has_cmd git || die "git is not installed." "Install git, or drop --no-deps."

  step "$DISPLAY_NAME"
  [[ "$LINK_BINS" == 1 ]] && need_sudo
  helper_sudo
  sync_repo
  build_backend
  install_binaries
  install_sys_helper
  remove_old_daemon
  legacy_notes
  compositor_setup
  exclusive_setup
  if [[ "$WITH_VOICE$WITH_DEPTH$WITH_SDDM" == *1* ]]; then
    step "Optional features"
    optional_features
  fi
  finish
}

main "$@"
