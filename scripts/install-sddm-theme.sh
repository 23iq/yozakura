#!/usr/bin/env bash
# Install the Yozakura SDDM theme (run with sudo):
#
#   sudo ./scripts/install-sddm-theme.sh [user]
#
# - copies assets/sddm/yozakura to /usr/share/sddm/themes/yozakura
# - creates /var/lib/yozakura-sddm owned by <user> (default: $SUDO_USER) and
#   world-readable, so the shell can update it without root and the sddm
#   greeter can read it; links it as the theme's theme.conf.user
# - writes /etc/sddm.conf.d/yozakura-theme.conf ([Theme] Current=yozakura),
#   backing up and commenting out any other [Theme] Current= setting
# - runs the first sync as <user>
#
# Undo: sudo ./scripts/uninstall-sddm-theme.sh
#   or just: sudo rm /etc/sddm.conf.d/yozakura-theme.conf

set -euo pipefail

# shellcheck source=scripts/lib/brand.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/brand.sh"

THEME_NAME="$BRAND_SDDM_THEME"
THEME_DIR="/usr/share/sddm/themes/$THEME_NAME"
DATA_DIR="$BRAND_SDDM_DATA_DIR"
CONF_DIR="/etc/sddm.conf.d"
CONF_FILE="$CONF_DIR/$BRAND_APP_ID-theme.conf"
REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
SRC_DIR="$REPO_DIR/assets/sddm/$THEME_NAME"
STAMP="$(date +%Y%m%d-%H%M%S)"

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31mxx\033[0m %s\n' "$*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || die "run as root: sudo $0 [user]"
[[ -f "$SRC_DIR/Main.qml" && -f "$SRC_DIR/metadata.desktop" ]] || die "theme sources not found in $SRC_DIR"

TARGET_USER="${1:-${SUDO_USER:-}}"
[[ -n "$TARGET_USER" && "$TARGET_USER" != "root" ]] || die "cannot determine the desktop user; pass it: sudo $0 <user>"
id "$TARGET_USER" >/dev/null 2>&1 || die "unknown user: $TARGET_USER"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

command -v sddm-greeter-qt6 >/dev/null 2>&1 || warn "sddm-greeter-qt6 not found; this theme needs SDDM built with Qt 6"

# 1. Theme files -------------------------------------------------------------
info "Installing theme to $THEME_DIR"
tmp_theme="$(mktemp -d "/usr/share/sddm/themes/.$BRAND_APP_ID.XXXXXX")"
cp -r "$SRC_DIR"/. "$tmp_theme"/
rm -f "$tmp_theme/theme.conf.user"
ln -s "$DATA_DIR/theme.conf" "$tmp_theme/theme.conf.user"
chown -R root:root "$tmp_theme"
chmod -R u=rwX,go=rX "$tmp_theme"
rm -rf "$THEME_DIR"
mv "$tmp_theme" "$THEME_DIR"

# 2. Shared data dir -----------------------------------------------------------
info "Preparing $DATA_DIR (owner $TARGET_USER, world-readable)"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$DATA_DIR"
chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR"
chmod -R u+rwX,go+rX,go-w "$DATA_DIR"

# 2b. Previous install of the legacy (Ambxst) theme -----------------------------
# Only removed when it is recognisably ours; its shared data dir is left for
# the old binary (rollback) and can be deleted by hand.
if [[ "$BRAND_LEGACY_APP_ID" != "$BRAND_APP_ID" ]]; then
  legacy_theme="/usr/share/sddm/themes/$BRAND_LEGACY_APP_ID"
  legacy_conf="$CONF_DIR/$BRAND_LEGACY_APP_ID-theme.conf"
  if [[ -f "$legacy_theme/metadata.desktop" ]] && grep -qx "Theme-Id=$BRAND_LEGACY_APP_ID" "$legacy_theme/metadata.desktop"; then
    info "Removing the previous $BRAND_LEGACY_APP_ID SDDM theme ($legacy_theme)"
    rm -rf "$legacy_theme"
  fi
  if [[ -f "$legacy_conf" ]] && grep -q "install-sddm-theme.sh" "$legacy_conf"; then
    info "Removing $legacy_conf"
    rm -f "$legacy_conf"
  fi
  [[ -d "/var/lib/$BRAND_LEGACY_APP_ID-sddm" ]] && info "Kept /var/lib/$BRAND_LEGACY_APP_ID-sddm (remove it once you no longer roll back)"
fi

# 3. SDDM config -----------------------------------------------------------------
info "Selecting theme in $CONF_FILE"
mkdir -p "$CONF_DIR"
# Neutralize other [Theme] Current= settings (later files and /etc/sddm.conf
# would otherwise override ours). Originals are kept as *.yozakura-bak-<date>.
for f in /etc/sddm.conf "$CONF_DIR"/*.conf; do
  [[ -f "$f" && "$f" != "$CONF_FILE" ]] || continue
  if awk '/^\[/{t=($0=="[Theme]")} t && /^[[:space:]]*Current[[:space:]]*=/{found=1} END{exit !found}' "$f"; then
    cp -a "$f" "$f.$BRAND_APP_ID-bak-$STAMP"
    awk -v app="$BRAND_APP_ID" '/^\[/{t=($0=="[Theme]")} t && /^[[:space:]]*Current[[:space:]]*=/{print "# disabled by " app " install-sddm-theme.sh: " $0; next} {print}' \
      "$f.$BRAND_APP_ID-bak-$STAMP" >"$f"
    warn "commented out [Theme] Current= in $f (backup: $f.$BRAND_APP_ID-bak-$STAMP)"
  fi
done
cat >"$CONF_FILE" <<EOF
# Installed by $BRAND_APP_ID scripts/install-sddm-theme.sh
# Remove this file to go back to the previous theme.
[Theme]
Current=$THEME_NAME
EOF
chmod 0644 "$CONF_FILE"

# 4. First sync as the desktop user ----------------------------------------------
info "Running first sync as $TARGET_USER"
if ! runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" \
  XDG_CACHE_HOME="$TARGET_HOME/.cache" XDG_CONFIG_HOME="$TARGET_HOME/.config" \
  bash "$REPO_DIR/scripts/sddm-sync.sh" --target "$DATA_DIR" --force; then
  warn "first sync failed; the theme still works with built-in fallbacks"
fi

# 5. Sanity check: the greeter user must be able to read the data -----------------
if id sddm >/dev/null 2>&1 && [[ -f "$DATA_DIR/theme.conf" ]]; then
  if runuser -u sddm -- test -r "$DATA_DIR/theme.conf"; then
    info "sddm user can read $DATA_DIR"
  else
    warn "sddm user cannot read $DATA_DIR/theme.conf; check permissions"
  fi
fi

info "Done. The theme is used at the next SDDM start (reboot, or 'sudo systemctl restart sddm' from a TTY)."
info "Preview without logging out: sddm-greeter-qt6 --test-mode --theme $THEME_DIR"
info "Rollback: sudo $REPO_DIR/scripts/uninstall-sddm-theme.sh"
