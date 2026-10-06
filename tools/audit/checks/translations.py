"""Translation keys (translations/*.json, flat "a.b.c" keys).

  * I18n.t("literal") whose key is missing from the reference language (error)
  * reference keys missing from another language (error; the UI would fall
    back to English) and keys only present in a non-reference language (warn)
  * reference keys never used (warn). A key counts as used when it appears as
    any string literal in QML/JS (covers key tables like `var keys = [...]`) or
    starts with a dynamic prefix: `I18n.t("prefix." + x)`, or any dotted
    literal ending in "." that is concatenated (`return "binds.action." + id`,
    key builders whose result reaches I18n.t through a variable), or starts
    with one of the config's `usedPrefixes` (keys sent by the Go backend,
    e.g. notify.request summaryKey/bodyKey, with the reason as the value).
"""
from __future__ import annotations

import json
import re

from lib.model import ERROR, REPO, WARN, Issue, repo_files
from lib.qmlscan import scan_file

CHECK = "translations"
CALL = re.compile(r'\bI18n\.t\(\s*(["\'`])')
CONCAT = re.compile(r'(["\'])([^\n"\']*)\1\s*\+')
KEY_PREFIX = re.compile(r"[a-z][\w-]*(\.[\w-]+)*\.")


def _flatten(obj: dict, prefix: str = "") -> dict[str, str]:
    out = {}
    for k, v in obj.items():
        if isinstance(v, dict):
            out.update(_flatten(v, f"{prefix}{k}."))
        else:
            out[prefix + k] = v
    return out


def _strings(obj) -> set[str]:
    if isinstance(obj, str):
        return {obj}
    if isinstance(obj, dict):
        return set().union(*(_strings(v) for v in obj.values())) if obj else set()
    if isinstance(obj, list):
        return set().union(*(_strings(v) for v in obj)) if obj else set()
    return set()


def run(cfg: dict) -> list[Issue]:
    c = cfg.get("translations", {})
    ref_lang = c.get("reference", "en")
    tdir = REPO / "translations"
    langs = {p.stem: _flatten(json.loads(p.read_text())) for p in sorted(tdir.glob("*.json"))
             if p.stem not in set(c.get("nonTranslationFiles", ["languages"]))}
    ref = langs.get(ref_lang, {})
    ignore_prefixes = tuple(c.get("ignorePrefixes", ["_meta."]))
    allow_missing = c.get("allowMissing", {})
    issues: list[Issue] = []

    literals: set[str] = set()
    prefixes: set[str] = set(c.get("usedPrefixes", {}))
    for f in repo_files(".qml", ".js"):
        raw = (REPO / f).read_text(errors="replace")
        scan = scan_file(REPO / f)
        literals.update(v for _, v in scan.strings)
        for m in CONCAT.finditer(scan.code):
            value = raw[m.start(2):m.end(2)]
            if KEY_PREFIX.fullmatch(value):
                prefixes.add(value)
        for m in CALL.finditer(scan.code):
            line = scan.code.count("\n", 0, m.start()) + 1
            quote_idx = m.end() - 1
            end = raw.find(m.group(1), quote_idx + 1)
            key = raw[quote_idx + 1:end]
            after = raw[end + 1:end + 40].lstrip()
            if after.startswith("+") or (m.group(1) == "`" and "${" in key):
                prefixes.add(key.split("${", 1)[0])
                continue
            if key and key not in ref and not key.startswith(ignore_prefixes):
                issues.append(Issue(CHECK, ERROR, f'I18n.t("{key}") is missing from {ref_lang}.json',
                                    file=f, line=line, key=key))

    for lang, table in langs.items():
        if lang == ref_lang:
            continue
        allowed = set(allow_missing.get(lang, {}))
        for key in sorted(set(ref) - set(table)):
            if not key.startswith(ignore_prefixes) and key not in allowed:
                issues.append(Issue(CHECK, ERROR, f"`{key}` missing from {lang}.json",
                                    file=f"translations/{lang}.json", key=f"{lang}:{key}"))
        for key in sorted(set(table) - set(ref)):
            if not key.startswith(ignore_prefixes):
                issues.append(Issue(CHECK, WARN, f"`{key}` only exists in {lang}.json (stale?)",
                                    file=f"translations/{lang}.json", key=f"{lang}:{key}"))

    # Data files whose strings are translation keys (e.g. the command
    # registry's title/description, resolved with I18n.t(entry.title)).
    for rel in c.get("keyDataFiles", []):
        literals.update(_strings(json.loads((REPO / rel).read_text())))

    allow_unused = set(c.get("allowUnused", {}))
    for key in sorted(ref):
        if key.startswith(ignore_prefixes) or key in literals or key in allow_unused:
            continue
        if any(p and key.startswith(p) for p in prefixes):
            continue
        issues.append(Issue(CHECK, WARN, f"`{key}` is never used", file=f"translations/{ref_lang}.json", key=key))
    return issues
