# shellcheck shell=bash
# App identity for shell scripts (source this file). Mirrors
# backend/pkg/brand and modules/globals/BrandActions.js. The legacy values
# name the project this one was forked from; they are only used for
# backwards compatibility (env var fallbacks).

BRAND_APP_ID="yozakura"
BRAND_DISPLAY_NAME="Yozakura"
BRAND_ENV_PREFIX="YOZAKURA_"
BRAND_LEGACY_APP_ID="ambxst"
BRAND_LEGACY_ENV_PREFIX="AMBXST_"
# Compositor IPC daemon binary (mirrors backend/pkg/brand.Daemon).
BRAND_DAEMON="yozd"

BRAND_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$BRAND_APP_ID"
BRAND_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$BRAND_APP_ID"
BRAND_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$BRAND_APP_ID"
# System-wide SDDM theme name and its shared, user-writable data dir.
BRAND_SDDM_THEME="$BRAND_APP_ID"
BRAND_SDDM_DATA_DIR="/var/lib/$BRAND_APP_ID-sddm"

export BRAND_APP_ID BRAND_DAEMON BRAND_DISPLAY_NAME BRAND_LEGACY_APP_ID BRAND_CONFIG_DIR BRAND_DATA_DIR BRAND_CACHE_DIR BRAND_SDDM_THEME BRAND_SDDM_DATA_DIR

brand_app_id() {
    printf '%s\n' "$BRAND_APP_ID"
}

# brand_env NAME [DEFAULT]: prints $<prefix>NAME, else $<legacy prefix>NAME,
# else DEFAULT. A variable set to an empty string still counts as set.
brand_env() {
    local name="$1" default="${2-}" var
    var="${BRAND_ENV_PREFIX}${name}"
    if [[ -n "${!var+x}" ]]; then
        printf '%s' "${!var}"
        return
    fi
    var="${BRAND_LEGACY_ENV_PREFIX}${name}"
    if [[ -n "${!var+x}" ]]; then
        printf '%s' "${!var}"
        return
    fi
    printf '%s' "$default"
}
