"""Register the bundled UI fonts (assets/fonts/ui) with Qt, like the shell's
FontRegistry.qml does at startup, so offscreen renders of a preset use the
families it names (creates the QGuiApplication when there is none yet)."""
from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def register(repo: Path = REPO) -> list[str]:
    from PySide6.QtGui import QFontDatabase, QGuiApplication

    if QGuiApplication.instance() is None:
        register.app = QGuiApplication([])  # kept alive; Harness reuses it
    families: set[str] = set()
    for f in sorted((repo / "assets/fonts/ui").rglob("*")):
        if f.suffix.lower() in (".ttf", ".otf"):
            fid = QFontDatabase.addApplicationFont(str(f))
            if fid >= 0:
                families.update(QFontDatabase.applicationFontFamilies(fid))
    return sorted(families)
