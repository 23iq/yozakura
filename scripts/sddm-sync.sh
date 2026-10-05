#!/usr/bin/env bash
# Sync the current Yozakura wallpaper, palette and fonts into the shared SDDM
# data directory so the "yozakura" SDDM theme matches the running shell.
#
# Runs as the desktop user (no root needed). The target directory is created
# by scripts/install-sddm-theme.sh, owned by the user and world-readable so
# the sddm greeter user can read it. If it does not exist, the theme is not
# installed and this script exits quietly.
#
# Usage: sddm-sync.sh [--target DIR] [--force] [--quiet]
#   --target DIR  output directory (default: $<PREFIX>SDDM_DIR or /var/lib/<app>-sddm)
#   --force       regenerate images even if the wallpaper did not change
#   --quiet       only print errors
#
# Output (all optional for the theme, which has built-in fallbacks):
#   wallpaper.jpg        sharp frame of the current wallpaper (videos: first/cached frame)
#   wallpaper-blur.jpg   pre-blurred version (matches the lockscreen blur)
#   avatar.png           ~/.face.icon / ~/.face, 256x256
#   fonts/*              theme fonts that live in the user's home (invisible to sddm)
#                        and the clock fonts bundled with the lock screen styles
#   theme.conf           palette, lock screen style/tone + style values, read by
#                        SDDM as theme.conf.user

set -uo pipefail
umask 022

# shellcheck source=scripts/lib/brand.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/brand.sh"

TARGET="$(brand_env SDDM_DIR "$BRAND_SDDM_DATA_DIR")"
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
FORCE=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --target)
    TARGET="$2"
    shift 2
    ;;
  --force)
    FORCE=1
    shift
    ;;
  --quiet)
    QUIET=1
    shift
    ;;
  -h | --help)
    sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "sddm-sync: unknown argument: $1" >&2
    exit 2
    ;;
  esac
done

log() { [[ $QUIET -eq 1 ]] || echo "sddm-sync: $*"; }
warn() { echo "sddm-sync: $*" >&2; }

if [[ ! -d "$TARGET" ]]; then
  log "$TARGET does not exist (theme not installed), nothing to do"
  exit 0
fi
if [[ ! -w "$TARGET" ]]; then
  warn "$TARGET is not writable by $(id -un); re-run the installer"
  exit 0
fi

for cmd in jq ffmpeg; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    warn "missing dependency: $cmd"
    exit 1
  fi
done

# Serialize concurrent runs (rapid wallpaper switching).
exec 9>"$TARGET/.lock"
if command -v flock >/dev/null 2>&1; then
  flock 9
fi

CACHE_DIR="$BRAND_CACHE_DIR"
CONFIG_DIR="$BRAND_CONFIG_DIR/config"

json_or_empty() {
  if [[ -r "$1" ]] && jq -e . "$1" >/dev/null 2>&1; then
    cat "$1"
  else
    echo '{}'
  fi
}

COLORS_JSON="$(json_or_empty "$CACHE_DIR/colors.json")"
WALLS_JSON="$(json_or_empty "$CACHE_DIR/wallpapers.json")"
THEME_JSON="$(json_or_empty "$CONFIG_DIR/theme.json")"
BAR_JSON="$(json_or_empty "$CONFIG_DIR/bar.json")"
LOCK_JSON="$(json_or_empty "$CONFIG_DIR/lockscreen.json")"

# ---------------------------------------------------------------- wallpaper --

TMP="$(mktemp -d "$TARGET/.tmp.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

wall="$(jq -r '.currentWall // ""' <<<"$WALLS_JSON")"
stamp_file="$TARGET/.wallpaper-stamp"
stamp=""
if [[ -n "$wall" && -r "$wall" ]]; then
  stamp="$wall|$(stat -c '%s|%Y' "$wall" 2>/dev/null)"
fi

if [[ -z "$stamp" ]]; then
  log "no readable wallpaper ($wall), keeping previous images"
elif [[ $FORCE -eq 0 && -s "$TARGET/wallpaper.jpg" && -s "$TARGET/wallpaper-blur.jpg" &&
  "$(cat "$stamp_file" 2>/dev/null)" == "$stamp" ]]; then
  log "wallpaper unchanged"
else
  src="$wall"
  ext="${wall##*.}"
  ext="${ext,,}"
  case "$ext" in
  mp4 | mkv | webm | mov | avi | m4v | gif)
    # Prefer the frame Yozakura already extracted for its own lockscreen.
    frame="$CACHE_DIR/lockscreen/$(basename "$wall").jpg"
    [[ -s "$frame" ]] && src="$frame"
    ;;
  esac

  # Sharp frame, capped at 4K width. -frames:v 1 handles images, GIFs and videos.
  if ffmpeg -nostdin -y -loglevel error -i "$src" -frames:v 1 \
    -vf "scale='min(3840,iw)':-2:flags=lanczos,format=yuvj420p" -q:v 2 \
    "$TMP/wallpaper.jpg" && [[ -s "$TMP/wallpaper.jpg" ]]; then
    # Moderate gaussian blur on a downscaled copy (cheap), similar to the
    # lockscreen MultiEffect (blur 0.7, blurMax 64).
    if ffmpeg -nostdin -y -loglevel error -i "$TMP/wallpaper.jpg" \
      -vf "scale=960:-2:flags=area,format=gbrp,gblur=sigma=7:steps=6,scale=1920:-2:flags=bicubic,format=yuvj420p" \
      -q:v 3 "$TMP/wallpaper-blur.jpg" && [[ -s "$TMP/wallpaper-blur.jpg" ]]; then
      mv -f "$TMP/wallpaper-blur.jpg" "$TARGET/wallpaper-blur.jpg"
    else
      warn "blur failed"
    fi
    mv -f "$TMP/wallpaper.jpg" "$TARGET/wallpaper.jpg"
    printf '%s' "$stamp" >"$stamp_file"
    log "wallpaper synced from $src"
  else
    warn "could not extract a frame from $src"
  fi
fi

# ------------------------------------------------------------------- avatar --

avatar_src=""
for f in "$HOME/.face.icon" "$HOME/.face"; do
  if [[ -r "$f" ]]; then
    avatar_src="$(readlink -f "$f")"
    break
  fi
done
if [[ -n "$avatar_src" ]]; then
  a_stamp="$avatar_src|$(stat -c '%s|%Y' "$avatar_src" 2>/dev/null)"
  if [[ $FORCE -eq 1 || ! -s "$TARGET/avatar.png" || "$(cat "$TARGET/.avatar-stamp" 2>/dev/null)" != "$a_stamp" ]]; then
    if ffmpeg -nostdin -y -loglevel error -i "$avatar_src" -frames:v 1 \
      -vf "scale=256:256:force_original_aspect_ratio=increase,crop=256:256" \
      "$TMP/avatar.png" && [[ -s "$TMP/avatar.png" ]]; then
      mv -f "$TMP/avatar.png" "$TARGET/avatar.png"
      printf '%s' "$a_stamp" >"$TARGET/.avatar-stamp"
    fi
  fi
else
  rm -f "$TARGET/avatar.png" "$TARGET/.avatar-stamp"
fi

# -------------------------------------------------------------------- fonts --

# Fonts under the user's home are invisible to the sddm user. Copy the ones
# the theme needs next to the other data; system fonts are used directly.
mkdir -p "$TARGET/fonts"
declare -A FONT_FILES=()
sync_font() {
  local key="$1" family="$2" matched file
  [[ -n "$family" ]] || return
  command -v fc-match >/dev/null 2>&1 || return
  matched="$(fc-match -f '%{family}' "$family" 2>/dev/null)"
  file="$(fc-match -f '%{file}' "$family" 2>/dev/null)"
  # fc-match always returns *something*; make sure it is the requested family.
  [[ ",$matched," == *",$family,"* ]] || return
  [[ -r "$file" ]] || return
  case "$file" in
  /usr/share/fonts/* | /usr/local/share/fonts/*) return ;; # visible to sddm already
  esac
  local dest="$TARGET/fonts/$key.${file##*.}"
  if ! cmp -s "$file" "$dest"; then
    cp -f "$file" "$TMP/font" && mv -f "$TMP/font" "$dest"
  fi
  FONT_FILES[$key]="$dest"
}

# Bundled font file -> fonts/<name> (stable names the theme.conf points at).
sync_file() {
  local key="$1" src="$2" dest="$TARGET/fonts/$3"
  [[ -r "$src" ]] || return
  if ! cmp -s "$src" "$dest"; then
    cp -f "$src" "$TMP/font" && mv -f "$TMP/font" "$dest"
  fi
  FONT_FILES[$key]="$dest"
}

ui_font="$(jq -r '.font // "Google Sans Flex"' <<<"$THEME_JSON")"
mono_font="$(jq -r '.monoFont // "monospace"' <<<"$THEME_JSON")"
sync_font font "$ui_font"
sync_font iconFont "Phosphor-Bold"
sync_font monoFont "$mono_font"
# Clock fonts of the lock screen styles (assets/fonts/clock in the repo).
CLOCK_FONTS="$REPO_DIR/assets/fonts/clock"
sync_file mincho "$CLOCK_FONTS/ShipporiMinchoB1-Medium.subset.ttf" clock-mincho-medium.ttf
sync_file minchoRegular "$CLOCK_FONTS/ShipporiMinchoB1-Regular.subset.ttf" clock-mincho-regular.ttf
sync_file minchoBold "$CLOCK_FONTS/ShipporiMinchoB1-ExtraBold.subset.ttf" clock-mincho-bold.ttf
sync_file gothic "$CLOCK_FONTS/LeagueGothic-Regular.ttf" clock-gothic.ttf
sync_file grotesk "$CLOCK_FONTS/SpaceGrotesk-Medium.otf" clock-grotesk-medium.otf
sync_file groteskBold "$CLOCK_FONTS/SpaceGrotesk-Bold.otf" clock-grotesk-bold.otf
# Drop stale copies.
for f in "$TARGET"/fonts/*; do
  [[ -e "$f" ]] || continue
  keep=0
  for v in "${FONT_FILES[@]}"; do [[ "$v" == "$f" ]] && keep=1; done
  [[ $keep -eq 1 ]] || rm -f "$f"
done

# --------------------------------------------------------------- theme.conf --

wall_path=""
blur_path=""
avatar_path=""
[[ -s "$TARGET/wallpaper.jpg" ]] && wall_path="$TARGET/wallpaper.jpg"
[[ -s "$TARGET/wallpaper-blur.jpg" ]] && blur_path="$TARGET/wallpaper-blur.jpg"
[[ -s "$TARGET/avatar.png" ]] && avatar_path="$TARGET/avatar.png"

# Mirrors modules/theme/Colors.qml (oled background, tinted surfaces) and
# Styling.getStyledRectConfig() for the variants the lockscreen uses.
jq -r -n \
  --argjson colors "$COLORS_JSON" \
  --argjson theme "$THEME_JSON" \
  --argjson bar "$BAR_JSON" \
  --argjson lock "$LOCK_JSON" \
  --arg wallpaper "$wall_path" \
  --arg blurred "$blur_path" \
  --arg avatar "$avatar_path" \
  --arg avatarUser "$(id -un)" \
  --arg fontFile "${FONT_FILES[font]:-}" \
  --arg iconFontFile "${FONT_FILES[iconFont]:-}" \
  --arg monoFontFile "${FONT_FILES[monoFont]:-}" \
  --arg minchoFile "${FONT_FILES[mincho]:-}" \
  --arg minchoRegularFile "${FONT_FILES[minchoRegular]:-}" \
  --arg minchoBoldFile "${FONT_FILES[minchoBold]:-}" \
  --arg gothicFile "${FONT_FILES[gothic]:-}" \
  --arg groteskFile "${FONT_FILES[grotesk]:-}" \
  --arg groteskBoldFile "${FONT_FILES[groteskBold]:-}" \
  --arg source "$wall" \
  --arg date "$(date -Iseconds)" --arg app "$BRAND_APP_ID" '
def hexval: ascii_downcase | explode
  | map(if . >= 97 then . - 87 else . - 48 end)
  | reduce .[] as $d (0; . * 16 + $d);
def norm: if type == "string" and test("^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
          then (if length == 9 then "#" + .[3:9] else . end) | ascii_downcase
          else null end;
def rgb: ltrimstr("#") | [.[0:2], .[2:4], .[4:6]] | map(hexval);
def hx: "0123456789abcdef" as $h
  | (if . < 0 then 0 elif . > 255 then 255 else . end | round) as $n
  | $h[($n / 16 | floor):($n / 16 | floor) + 1] + $h[($n % 16):($n % 16) + 1];
def tint($base; $over; $a):
  [($base | rgb), ($over | rgb)] | transpose
  | map(.[0] * (1 - $a) + .[1] * $a | hx) | "#" + join("");
# Lock screen styles and their tones, own tone first. Mirrors
# modules/lockscreen/styles/LockStyleRegistry.js (styles + resolveTone).
def lockTones: {
  glass: ["dark", "light"], paper: ["light", "dark"], terminal: ["dark", "light"],
  aurora: ["light", "dark"], neon: ["dark"], poster: ["dark", "light"]
};
(($lock.style // "glass") | tostring) as $s0
| (if lockTones | has($s0) then $s0 else "glass" end) as $style
| lockTones[$style] as $tones
| (($lock.tone // "style") | tostring) as $t
| (if $t == "light" or $t == "dark" then $t
   elif $t == "theme" then (if ($theme.lightMode // false) then "light" else "dark" end)
   else $tones[0] end) as $want
| (if ($tones | index($want)) != null then $want else $tones[0] end) as $tone
| ($lock.blur | if type == "number" and (. == -1 or (. >= 0 and . <= 1)) then . else -1 end) as $blur
| ($colors | with_entries(.value |= norm) | with_entries(select(.value != null))) as $raw
| ({ background: "#1a1111", overBackground: "#f1dedd" } + $raw) as $c0
| (if ($theme.oledMode // false) then "#000000" else $c0.background end) as $bg
| ($c0 + {
    background: $bg,
    surface: tint($bg; $c0.overBackground; 0.1),
    surfaceBright: tint($bg; $c0.overBackground; 0.2)
  }) as $pal
| def resolve($name; $fallback):
    (if ($name | type) == "string" and ($name | startswith("#")) then ($name | norm)
     else $pal[$name] end) // $fallback;
  def variant($key; $dflt):
    ($theme[$key] // {}) as $v
    | ($v.gradient // [[$dflt.color, 0]]) as $g
    | {
        color: (if ($v.gradientType // "linear") == "halftone"
                then resolve($v.halftoneBackgroundColor // $dflt.color; $pal.background)
                else resolve($g[0][0]; $pal.background) end),
        item: resolve($v.itemColor // $dflt.item; $pal.overBackground),
        opacity: ($v.opacity // $dflt.opacity),
        borderColor: resolve(($v.border // [])[0] // "surfaceBright"; $pal.surfaceBright),
        borderWidth: (($v.border // [])[1] // 0)
      };
  variant("srBg"; {color: "background", item: "overBackground", opacity: 0.78}) as $vbg
| variant("srCommon"; {color: "surface", item: "overBackground", opacity: 0.85}) as $vcommon
| variant("srError"; {color: "error", item: "overError", opacity: 1}) as $verror
| def q: tostring | gsub("\\\\"; "\\\\") | gsub("\""; "\\\"") | "\"" + . + "\"";
  [
    "; Generated by \($app) scripts/sddm-sync.sh at \($date)",
    "; Source wallpaper: \($source)",
    "[General]",
    "background=\($wallpaper | q)",
    "backgroundBlurred=\($blurred | q)",
    "avatar=\($avatar | q)",
    "avatarUser=\($avatarUser | q)",
    "font=\(($theme.font // "Google Sans Flex") | q)",
    "fontFile=\($fontFile | q)",
    "iconFont=\("Phosphor-Bold" | q)",
    "iconFontFile=\($iconFontFile | q)",
    "fontSize=\($theme.fontSize // 14)",
    "roundness=\($theme.roundness // 16)",
    "use12h=\($bar.use12hFormat // false)",
    "position=\(($lock.position // "bottom") | q)",
    "style=\($style | q)",
    "tone=\($tone | q)",
    "blur=\($blur)",
    "showStatus=\(if $lock.showStatus == false then false else true end)",
    "monoFont=\(($theme.monoFont // "monospace") | q)",
    "monoFontFile=\($monoFontFile | q)",
    "minchoFile=\($minchoFile | q)",
    "minchoRegularFile=\($minchoRegularFile | q)",
    "minchoBoldFile=\($minchoBoldFile | q)",
    "gothicFile=\($gothicFile | q)",
    "groteskFile=\($groteskFile | q)",
    "groteskBoldFile=\($groteskBoldFile | q)",
    "enableCorners=\($theme.enableCorners // true)",
    "shadowColor=\(resolve($theme.shadowColor // "shadow"; "#000000") | q)",
    "bgColor=\($vbg.color | q)",
    "bgItem=\($vbg.item | q)",
    "bgOpacity=\($vbg.opacity)",
    "bgBorderColor=\($vbg.borderColor | q)",
    "bgBorderWidth=\($vbg.borderWidth)",
    "commonColor=\($vcommon.color | q)",
    "commonItem=\($vcommon.item | q)",
    "commonOpacity=\($vcommon.opacity)",
    "errorColor=\($verror.color | q)",
    "errorItem=\($verror.item | q)"
  ]
  + ($pal | to_entries | sort_by(.key) | map("color_\(.key)=\(.value | q)"))
  | join("\n")
' >"$TMP/theme.conf" || {
  warn "failed to generate theme.conf"
  exit 1
}

mv -f "$TMP/theme.conf" "$TARGET/theme.conf"
chmod -R a+rX "$TARGET" 2>/dev/null
log "theme.conf written to $TARGET"
