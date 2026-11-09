"""Kit-literals audit: hand-made spacing, sizes and boxes outside the UI kit.

Screens are built from the kit (modules/components/kit: Space / Type / Look
tokens, Icon, Group, ...). This check counts, per directory of modules/, the
QML lines that bypass it:
  spacing      a numeric literal for spacing / margins / padding
               (`spacing: 8`, `anchors.leftMargin: 12`, `Layout.topMargin: 4`)
  font-size    a literal `font.pixelSize` (`20`, `Config.theme.fontSize - 2`)
  rectangle    a raw `Rectangle {` (StyledRect / kit boxes instead)
  text         a raw `Text {` (KitText / Icon instead)
  radius       `Styling.radius(n)` with a literal offset (Look.radius(role))
The kit and the theme (modules/components/kit, modules/theme) define the
tokens and are exempt. Today's counts are a ratchet baseline
(tools/lint/baselines/kit-literals.json): a directory may only go down. A
new directory or a higher count fails; lower counts ask for a refresh
(`make kit-literals-baseline`), never the other way round.
"""
from __future__ import annotations

import json
import os
import re
from collections import Counter

from lib.model import ERROR, INFO, REPO, WARN, Issue, repo_files
from lib.qmlscan import scan_text

CHECK = "kit-literals"
BASELINE = REPO / "tools" / "lint" / "baselines" / "kit-literals.json"
EXEMPT = ("modules/components/kit/", "modules/theme/")
RULES = ("spacing", "font-size", "rectangle", "text", "radius")

_NUM = r"-?\d+(?:\.\d+)?"
_SPACING = re.compile(
    r"^\s*(?:anchors\.|Layout\.)?(?:spacing|rowSpacing|columnSpacing|(?:left|right|top|bottom|horizontal|vertical)?"
    r"(?:[Mm]argins?|[Pp]adding))\s*:\s*(" + _NUM + r")\s*;?\s*$")
_FONT = re.compile(r"\bfont\.pixelSize\s*:\s*(?:" + _NUM + r"\s*(?:[;}]|$)|[^;}]*\bfontSize\s*[-+*]\s*\d)")
_RECT = re.compile(r"^\s*(?:[\w.]+\s*:\s*)?Rectangle\s*\{")
_TEXT = re.compile(r"^\s*(?:[\w.]+\s*:\s*)?Text\s*\{")
_RADIUS = re.compile(r"\bStyling\.radius\(\s*[-+]?\s*[1-9]\d*(?:\.\d+)?\s*\)")


def count_text(src: str) -> Counter:
    """Rule counts of one QML source (comments ignored, strings blanked)."""
    out: Counter = Counter()
    for line in scan_text(src).code.split("\n"):
        m = _SPACING.match(line)
        if m and float(m.group(1)) != 0:
            out["spacing"] += 1
        out["font-size"] += len(_FONT.findall(line))
        if _RECT.match(line):
            out["rectangle"] += 1
        if _TEXT.match(line):
            out["text"] += 1
        out["radius"] += len(_RADIUS.findall(line))
    return out


def directory_of(rel: str) -> str:
    return rel.rsplit("/", 1)[0]


def analyze(sources: dict[str, str]) -> dict[str, dict[str, int]]:
    """{directory: {rule: count}} without zero entries, sorted."""
    per: dict[str, Counter] = {}
    for rel, src in sources.items():
        if not rel.startswith("modules/") or rel.startswith(EXEMPT):
            continue
        c = count_text(src)
        if c:
            per.setdefault(directory_of(rel), Counter()).update(c)
    return {d: {r: per[d][r] for r in RULES if per[d][r]} for d in sorted(per) if any(per[d].values())}


def compare(current: dict, baseline: dict) -> tuple[list[str], list[str]]:
    """(new findings, improvements) as messages."""
    new, better = [], []
    for d, rules in current.items():
        base = baseline.get(d, {})
        for r, n in rules.items():
            b = base.get(r, 0)
            if n > b:
                new.append(f"{d}: {r} {n} > baseline {b} (use the kit tokens: Space / Type / Look, KitText, Icon)")
    for d, rules in baseline.items():
        for r, b in rules.items():
            n = current.get(d, {}).get(r, 0)
            if n < b:
                better.append(f"{d}: {r} {n} < baseline {b}")
    return new, better


def _sources() -> dict[str, str]:
    files = repo_files(".qml", exclude=("backend/", "tests/", "tools/", "docs/", "assets/"))
    return {f: (REPO / f).read_text(errors="replace") for f in files if f.startswith("modules/")}


def run(cfg: dict) -> list[Issue]:
    current = analyze(_sources())
    if os.environ.get("AUDIT_UPDATE_KIT_LITERALS"):
        BASELINE.write_text(json.dumps(current, indent=1) + "\n")
        return [Issue(CHECK, INFO, f"wrote {BASELINE.relative_to(REPO)}")]
    baseline = json.loads(BASELINE.read_text()) if BASELINE.exists() else {}
    new, better = compare(current, baseline)
    issues = [Issue(CHECK, ERROR, m, file=m.split(":", 1)[0]) for m in new]
    issues += [Issue(CHECK, WARN, f"improved, refresh the baseline with `make kit-literals-baseline`: {m}") for m in better]
    totals = Counter()
    for rules in current.values():
        totals.update(rules)
    issues.append(Issue(CHECK, INFO, "outside the kit: " + ", ".join(f"{totals[r]} {r}" for r in RULES)
                        + f" in {len(current)} director(ies) (baselined, may only go down)"))
    return issues
