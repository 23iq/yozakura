"""Settings snapshot coverage (modules/globals/GlobalStates.qml).

The settings panels take a snapshot before the first edit and restore it on
"Discard". Only keys listed in GlobalStates' key lists are snapshotted:
  theme       -> _simpleThemeProps + every `sr*` variant (_srVariantProps)
  shell panel -> _shellSections { domain: [keys] }
  compositor  -> _compositorProps
A config key missing from its list is silently NOT reverted by Discard
(warning). A listed key that no longer exists is stale (warning). Domains that
have no list at all are reported once (info).
"""
from __future__ import annotations

import re

from lib import configmodel
from lib.model import INFO, REPO, WARN, Issue
from lib.qmlscan import find_block_end, scan_text

CHECK = "snapshot-keys"
GLOBAL_STATES = "modules/globals/GlobalStates.qml"
_STR = re.compile(r'"([^"]*)"')


def _list_body(raw: str, name: str) -> str | None:
    m = re.search(rf"property\s+var\s+{name}\s*:\s*([\[{{])", raw)
    if not m:
        return None
    start = m.end(1) - 1
    if m.group(1) == "{":
        return raw[start:find_block_end(scan_text(raw).code, start) + 1]
    return raw[start:raw.index("]", start) + 1]


def _sections(body: str) -> dict[str, list[str]]:
    return {k: _STR.findall(v) for k, v in re.findall(r'"(\w+)"\s*:\s*\[([^\]]*)\]', body)}


def run(cfg: dict) -> list[Issue]:
    c = cfg.get("snapshotKeys", {})
    allow = set(c.get("notSnapshotted", {}))
    raw = (REPO / GLOBAL_STATES).read_text()
    domains, _ = configmodel.load()
    by_name = {d.name: d for d in domains}
    issues: list[Issue] = []

    def check(domain: str, listed: list[str], keys: list[str], list_name: str) -> None:
        for k in keys:
            full = f"{domain}.{k}"
            if k not in listed and full not in allow:
                issues.append(Issue(CHECK, WARN, f"`{full}` is not in GlobalStates.{list_name}: "
                                    "settings Discard will not revert it", file=GLOBAL_STATES, key=full))
        for k in listed:
            if k not in keys and f"{domain}.{k}" not in allow:
                issues.append(Issue(CHECK, WARN, f"GlobalStates.{list_name} lists `{domain}.{k}` "
                                    "which is not a config key", file=GLOBAL_STATES, key=f"{domain}.{k}"))

    covered = set()
    theme = by_name.get("theme")
    simple, variant = _list_body(raw, "_simpleThemeProps"), _list_body(raw, "_srVariantProps")
    if theme and simple and variant:
        covered.add("theme")
        sr = [k for k, v in theme.adapter.items() if k.startswith("sr") and v]
        check("theme", _STR.findall(simple), [k for k in theme.adapter if k not in sr], "_simpleThemeProps")
        variant_keys = set(_STR.findall(variant)) | {"gradient", "border"}
        missing: dict[str, list[str]] = {}
        for name in sr:
            for k in theme.adapter[name]:
                if k not in variant_keys and f"theme.sr*.{k}" not in allow:
                    missing.setdefault(k, []).append(name)
        for k, names in missing.items():
            issues.append(Issue(CHECK, WARN, f"`theme.sr*.{k}` ({len(names)} variants) is not in "
                                "GlobalStates._srVariantProps", file=GLOBAL_STATES, key=f"theme.sr*.{k}"))
    body = _list_body(raw, "_shellSections")
    for section, listed in (_sections(body) if body else {}).items():
        if section in by_name:
            covered.add(section)
            check(section, listed, list(by_name[section].adapter), f"_shellSections.{section}")
    comp = _list_body(raw, "_compositorProps")
    if comp and "compositor" in by_name:
        covered.add("compositor")
        check("compositor", _STR.findall(comp), list(by_name["compositor"].adapter), "_compositorProps")
    for d in domains:
        if d.name not in covered and d.name not in set(c.get("ignoreDomains", [])):
            issues.append(Issue(CHECK, INFO, f"domain `{d.name}` has no snapshot list (Discard cannot revert it)",
                                file=GLOBAL_STATES, key=d.name))
    return issues
