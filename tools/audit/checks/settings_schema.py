"""Settings schema (modules/settings/schema/*.js) stays in sync with the shell.

For every declared setting (SchemaUtil.validateCategory, run in node):
  * its keys have a default in config/defaults (or are wallpaper keys);
  * label/description/option/topic i18n keys exist in translations/en.json;
  * types are known; selectors have options containing the default; sliders
    and numbers have min < max with the default in range; visibleWhen /
    enabledWhen only read existing keys; custom editors and previews are
    registered in modules/settings/Registry.js.
Plus: registry files and legacy panel sources exist, LegacyLink targets are
categories, and keys of staged domains are in the GlobalStates snapshot
lists (otherwise "Discard" in the settings window would not revert them).
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess

from lib.model import ERROR, REPO, Issue

CHECK = "settings-schema"
SCHEMA_DIR = "modules/settings/schema"
GLOBAL_STATES = REPO / "modules/globals/GlobalStates.qml"


def _snapshot_lists() -> dict[str, set[str]]:
    raw = GLOBAL_STATES.read_text()
    out: dict[str, set[str]] = {}
    m = re.search(r"_shellSections:\s*\{(.*?)\n    \}", raw, re.S)
    if m:
        for dom, body in re.findall(r'"(\w+)"\s*:\s*\[([^\]]*)\]', m.group(1)):
            out[dom] = set(re.findall(r'"(\w+)"', body))
    for name, dom in (("_simpleThemeProps", "theme"), ("_compositorProps", "compositor")):
        m = re.search(rf"{name}:\s*\[(.*?)\]", raw, re.S)
        if m:
            out[dom] = set(re.findall(r'"(\w+)"', m.group(1)))
    return out


def run(cfg: dict) -> list[Issue]:
    if not shutil.which("node"):
        return []
    r = subprocess.run(["node", str(REPO / "tools/audit/lib/settings_schema.cjs"), str(REPO)],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return [Issue(CHECK, ERROR, f"schema failed to load: {r.stderr.strip()[-400:]}", file=SCHEMA_DIR)]
    data = json.loads(r.stdout)
    issues: list[Issue] = []
    ids = {c["id"] for c in data["categories"]}
    for rel in data["registry"]:
        if not (REPO / "modules/settings" / rel).is_file():
            issues.append(Issue(CHECK, ERROR, f"Registry.js names a missing file {rel}",
                                file="modules/settings/Registry.js", key=rel))
    snapshots = _snapshot_lists()
    for cat in data["categories"]:
        for p in cat["problems"]:
            issues.append(Issue(CHECK, ERROR, p, file=SCHEMA_DIR, key=f"{cat['id']}:{p}"))
        for target in cat["links"]:
            if target not in ids:
                issues.append(Issue(CHECK, ERROR, f"{cat['id']}: link to unknown category '{target}'",
                                    file=SCHEMA_DIR, key=f"{cat['id']}:{target}"))
        for key in cat["keys"]:
            domain, prop = (key.split(".") + [""])[:2]
            # theme.sr* surface roles are snapshotted as a group (_getSrVariantNames)
            if domain == "theme" and prop.startswith("sr"):
                continue
            if domain in snapshots and prop not in snapshots[domain]:
                issues.append(Issue(CHECK, ERROR,
                                    f"{cat['id']}: `{domain}.{prop}` is edited by the settings but not in the "
                                    f"GlobalStates snapshot list for '{domain}' (Discard would not revert it)",
                                    file=str(GLOBAL_STATES.relative_to(REPO)), key=f"{cat['id']}:{key}"))
    return issues
