"""The visual languages (theme.language) as modules/theme/VisualLanguage.js
declares them: the one list every render tool and kit test iterates, so a
new language shows up in every sheet without touching the tools. Pure (no
Qt import): safe to import before the headless platform is set up."""
from __future__ import annotations

import json
import re
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "modules" / "theme" / "VisualLanguage.js"


def languages(source: Path = SOURCE) -> list[str]:
    m = re.search(r"^var LANGUAGES\s*=\s*(\[[^\]]*\])", source.read_text(), re.M)
    if not m:
        raise RuntimeError(f"no LANGUAGES list in {source}")
    return json.loads(m.group(1))


LANGUAGES = languages()
