"""App identity for Python helpers (mirrors scripts/lib/brand.sh).

The legacy values name the project this one was forked from; they are only
used for backwards compatibility (env var fallbacks).
"""
from __future__ import annotations

import os

APP_ID = "yozakura"
DISPLAY_NAME = "Yozakura"
ENV_PREFIX = "YOZAKURA_"
LEGACY_APP_ID = "ambxst"
LEGACY_ENV_PREFIX = "AMBXST_"
# Compositor IPC daemon binary (mirrors backend/pkg/brand.Daemon).
DAEMON = "yozd"


def _xdg(var: str, default: str) -> str:
    return os.environ.get(var) or os.path.join(os.path.expanduser("~"), default)


CONFIG_DIR = os.path.join(_xdg("XDG_CONFIG_HOME", ".config"), APP_ID)
DATA_DIR = os.path.join(_xdg("XDG_DATA_HOME", ".local/share"), APP_ID)
CACHE_DIR = os.path.join(_xdg("XDG_CACHE_HOME", ".cache"), APP_ID)


def brand_app_id() -> str:
    return APP_ID


def brand_env(name: str, default: str | None = None) -> str | None:
    """$<prefix>NAME, falling back to $<legacy prefix>NAME, then default."""
    for prefix in (ENV_PREFIX, LEGACY_ENV_PREFIX):
        value = os.environ.get(prefix + name)
        if value is not None:
            return value
    return default
