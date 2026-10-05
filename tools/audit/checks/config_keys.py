"""Config schema consistency.

  * every key in config/defaults/<domain>.js has a property in the Config.qml
    adapter of that domain, and vice versa (error);
  * every defaults/*.js file is wired into Config.qml (error);
  * `Config.<domain>.<key>` used anywhere in QML/JS names a key that exists in
    the adapter (error) - catches typos and keys removed from the schema.
"""
from __future__ import annotations

import re

from lib import configmodel
from lib.model import ERROR, INFO, REPO, Issue, repo_files
from lib.qmlscan import scan_file

CHECK = "config-keys"
USE = re.compile(r"\bConfig\.(\w+)\.(\w+)\b")
# QtObject / JsonAdapter API that is not a config key.
API = {"writeAdapter", "objectName", "toString", "destroyed", "hasOwnProperty"}


def _inside_var(key: str, tree: dict[str, dict | None]) -> bool:
    """True when some ancestor of `key` is a leaf (a free-form `var`) in `tree`."""
    parts = key.split(".")
    for i in range(1, len(parts)):
        ancestor = ".".join(parts[:i])
        if ancestor in tree and tree[ancestor] is None:
            return True
    return False


def _compare(d: configmodel.Domain, allow: set[str]) -> list[Issue]:
    issues = []
    qml = configmodel.flatten(d.adapter)
    js = configmodel.flatten(d.defaults)
    for key in sorted(set(js) - set(qml)):
        if _inside_var(key, qml):
            continue  # inside a free-form `var` value, at any depth
        full = f"{d.name}.{key}"
        if full not in allow:
            issues.append(Issue(CHECK, ERROR, f"`{full}` has a default but no adapter property (run `make schema`)",
                                file=d.defaults_file, key=full))
    for key in sorted(set(qml) - set(js)):
        if _inside_var(key, js):
            continue
        full = f"{d.name}.{key}"
        if full not in allow:
            issues.append(Issue(CHECK, ERROR, f"`{full}` is an adapter property without a default in "
                                f"{d.defaults_file}", file=d.adapter_file, line=d.adapter_line, key=full))
    return issues


def run(cfg: dict) -> list[Issue]:
    c = cfg.get("configKeys", {})
    allow = set(c.get("allow", {}))
    domains, props = configmodel.load()
    issues: list[Issue] = []
    if any(d.defaults is None for d in domains):
        issues.append(Issue(CHECK, INFO, "node not found: defaults/*.js not evaluated, schema comparison skipped"))
    wired = {d.defaults_file for d in domains}
    for f in repo_files(".js"):
        if f.startswith("config/defaults/") and f not in wired:
            issues.append(Issue(CHECK, ERROR, "defaults file is not loaded by Config.qml (ConfigFile)",
                                file=f, key=f))
    for d in domains:
        if not d.adapter:
            issues.append(Issue(CHECK, ERROR, f"no JsonAdapter found for loader `{d.loader}`",
                                file="config/Config.qml", key=d.name))
        elif d.defaults is not None:
            issues.extend(_compare(d, allow))

    by_name = {d.name: d for d in domains}
    unknown_allow = set(c.get("allowUnknownUse", {}))
    for f in repo_files(".qml", ".js"):
        scan = scan_file(REPO / f)
        uses: dict[str, list[int]] = {}
        for m in USE.finditer(scan.code):
            domain = props.get(m.group(1))
            if not domain or m.group(2) in by_name[domain].adapter or m.group(2) in API:
                continue
            full = f"{m.group(1)}.{m.group(2)}"
            if full not in unknown_allow:
                uses.setdefault(full, []).append(scan.code.count("\n", 0, m.start()) + 1)
        for full, lines in uses.items():
            more = f" (lines {', '.join(map(str, sorted(set(lines))))})" if len(set(lines)) > 1 else ""
            issues.append(Issue(CHECK, ERROR, f"`Config.{full}` is not a key of the "
                                f"`{props[full.split('.')[0]]}` adapter{more}", file=f, line=lines[0], key=full))
    return issues
