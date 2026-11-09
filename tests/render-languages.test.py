"""Render tools cover every visual language: the shared list comes from
VisualLanguage.js and the sweep renders each sheet in each language."""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tests" / "lib"))
sys.path.insert(0, str(REPO / "tools" / "render"))
import bar_matrix  # noqa: E402
import languages  # noqa: E402
import render_sweep  # noqa: E402

langs = languages.LANGUAGES
assert langs == ["ink", "glass", "tiles", "classic", "device"], langs
assert bar_matrix.LANGUAGES == langs, "the bar matrix renders every language"

plan = render_sweep.sheets(langs, "dark")
assert set(plan) == {"kit", "kit-bold", "settings", "dashboard", "bar-matrix", "osd", "dashtabs"}, plan
for name, argv in plan.items():
    assert (REPO / "tools" / "render" / argv[0]).is_file(), argv[0]
    joined = " ".join(argv)
    if name != "bar-matrix":  # the matrix iterates bar_matrix.LANGUAGES itself
        assert all(lang in joined for lang in langs), (name, argv)

# Tools with their own default list read it from languages.py, not a literal
for tool in ("island_render.py", "branch_render.py", "activitychip_render.py", "barchips_render.py",
             "strips_render.py", "sentence_render.py", "presetstatus_render.py", "weatherfx_render.py",
             "cardhost_render.py", "lighting_render.py"):
    src = (REPO / "tools" / "render" / tool).read_text()
    assert "from languages import LANGUAGES" in src and 'default="ink,glass,tiles"' not in src, tool
# ... and no render tool keeps a literal list of languages as its default.
LITERAL = re.compile(r"""(default=|or |choices=)\[?["']ink(["'], |,)""")
for tool in sorted((REPO / "tools" / "render").glob("*.py")):
    for n, line in enumerate(tool.read_text().splitlines(), 1):
        assert not LITERAL.search(line), f"{tool.name}:{n}: a literal language list ({line.strip()})"
print("render languages: every tool and the sweep cover all five languages")
