#!/usr/bin/env bash
# Remove the Yozakura SDDM theme and switch SDDM back to another theme
# (default: breeze). Run with sudo:
#
#   sudo ./scripts/uninstall-sddm-theme.sh [theme] [--purge]
#
#   theme    theme to switch to (default: breeze; "" = SDDM's default)
#   --purge  also delete /var/lib/yozakura-sddm
#
# Emergency rollback without this script (e.g. from a TTY):
#   sudo rm /etc/sddm.conf.d/yozakura-theme.conf && sudo systemctl restart sddm

set -euo pipefail

# shellcheck source=scripts/lib/brand.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/brand.sh"

THEME_DIR="/usr/share/sddm/themes/$BRAND_SDDM_THEME"
DATA_DIR="$BRAND_SDDM_DATA_DIR"
CONF_DIR="/etc/sddm.conf.d"
CONF_FILE="$CONF_DIR/$BRAND_APP_ID-theme.conf"
FALLBACK_CONF="$CONF_DIR/theme.conf"

FALLBACK="breeze"
PURGE=0
for arg in "$@"; do
  case "$arg" in
  --purge) PURGE=1 ;;
  *) FALLBACK="$arg" ;;
  esac
done

[[ $EUID -eq 0 ]] || {
  echo "run as root: sudo $0 [theme] [--purge]" >&2
  exit 1
}

rm -f "$CONF_FILE"
echo ":: removed $CONF_FILE"

if [[ -n "$FALLBACK" ]]; then
  if [[ -d "/usr/share/sddm/themes/$FALLBACK" ]]; then
    mkdir -p "$CONF_DIR"
    printf '# Written by %s uninstall-sddm-theme.sh\n[Theme]\nCurrent=%s\n' "$BRAND_APP_ID" "$FALLBACK" >"$FALLBACK_CONF"
    echo ":: SDDM theme set to $FALLBACK ($FALLBACK_CONF)"
  else
    echo "!! theme '$FALLBACK' not installed; leaving SDDM's default" >&2
  fi
fi

rm -rf "$THEME_DIR"
echo ":: removed $THEME_DIR"

if [[ $PURGE -eq 1 ]]; then
  rm -rf "$DATA_DIR"
  echo ":: removed $DATA_DIR"
fi

shopt -s nullglob
baks=(/etc/sddm.conf."$BRAND_APP_ID"-bak-* "$CONF_DIR"/*."$BRAND_APP_ID"-bak-*)
if [[ ${#baks[@]} -gt 0 ]]; then
  echo ":: backups of configs edited by the installer (restore manually if wanted):"
  printf '   %s\n' "${baks[@]}"
fi
