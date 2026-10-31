"""Backend method audit: every JSON-RPC method the QML calls must exist.

The daemon's registry (assets/schema/ipc-methods.json, generated from the
registered services by backend/pkg/daemon/ipc_registry_test.go; `make schema`)
lists every `service.method` and which services can be subscribed. This check
extracts the method strings from QML/JS and fails on unknown ones:

  * ``BackendService.call("svc.method"`` / ``.notify(`` and the wrappers and
    helpers listed in config.json ``ipcMethods.wrappers``
    ({"pattern": regex, "prefix": "svc.", "files": [optional]}),
  * ``BackendService.addSubscription(["svc", ...]`` service names
    (a service without ``Subscribe`` in the registry is an error).

Method names that are not string literals (``call(method, ...)``,
``"svc." + name``) cannot be checked; they are reported as warnings unless
the file is listed in ``ipcMethods.dynamicAllow`` with a reason (a
``prefix`` concatenation is still checked against the service name).
"""
from __future__ import annotations

import json
import re

from lib.model import ERROR, REPO, WARN, Issue, repo_files
from lib.qmlscan import scan_text

CHECK = "ipc-methods"
REGISTRY = REPO / "assets" / "schema" / "ipc-methods.json"

_CALL = re.compile(r"\bBackendService\s*\.\s*(?:call|notify)\s*\(")
_SUB = re.compile(r"\bBackendService\s*\.\s*addSubscription\s*\(")
_QUOTE = "\"'"


def _line(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def _literal(text: str, i: int) -> tuple[str | None, int]:
    """String literal starting at i (after spaces) -> (value, index after it); (None, i) if not one."""
    while i < len(text) and text[i] in " \t\r\n":
        i += 1
    if i >= len(text) or text[i] not in _QUOTE:
        return None, i
    q, j = text[i], i + 1
    while j < len(text) and text[j] != q:
        j += 2 if text[j] == "\\" else 1
    return text[i + 1:j], j + 1


def _concat_follows(text: str, i: int) -> bool:
    while i < len(text) and text[i] in " \t\r\n":
        i += 1
    return text[i:i + 1] == "+"


def extract(rel: str, text: str, wrappers: list[dict]) -> dict:
    """{"methods": [(line, name)], "dynamic": [(line, prefix|"")], "subs": [(line, name)], "dynsubs": [line]}."""
    code = scan_text(text).code  # comments blanked, same offsets as text
    out = {"methods": [], "dynamic": [], "subs": [], "dynsubs": []}

    def handle(m_end: int, line: int, prefix: str) -> None:
        val, end = _literal(text, m_end)
        if val is None:
            out["dynamic"].append((line, ""))
        elif _concat_follows(text, end):
            out["dynamic"].append((line, prefix + val))
        else:
            out["methods"].append((line, prefix + val))

    for m in _CALL.finditer(code):
        handle(m.end(), _line(text, m.start()), "")
    for w in wrappers:
        if w.get("files") and rel not in w["files"]:
            continue
        for m in re.finditer(w["pattern"] + r"\s*\(", code):
            handle(m.end(), _line(text, m.start()), w.get("prefix", ""))
    for m in _SUB.finditer(code):
        i = m.end()
        while i < len(code) and code[i] in " \t\r\n":
            i += 1
        line = _line(text, m.start())
        if code[i:i + 1] != "[":
            out["dynsubs"].append(line)
            continue
        end = code.find("]", i)
        j = i + 1
        while j < end:
            val, nxt = _literal(text, j)
            if val is None:
                if code[j] not in " \t\r\n,":
                    out["dynsubs"].append(line)
                    break
                j += 1
            else:
                out["subs"].append((line, val))
                j = nxt
    return out


def load_registry() -> dict[str, dict]:
    data = json.loads(REGISTRY.read_text())
    return {s["name"]: s for s in data["services"]}


def verify(rel: str, found: dict, registry: dict[str, dict], dynamic_allow: dict) -> list[Issue]:
    issues: list[Issue] = []
    for line, name in found["methods"]:
        svc, _, method = name.partition(".")
        if svc not in registry:
            issues.append(Issue(CHECK, ERROR, f'unknown backend service in "{name}"', rel, line, name))
        elif method not in registry[svc]["methods"]:
            issues.append(Issue(CHECK, ERROR, f'unknown backend method "{name}" (service {svc} has no "{method}")',
                                rel, line, name))
    for line, prefix in found["dynamic"]:
        svc = prefix.split(".")[0] if "." in prefix else ""
        if svc and svc not in registry:
            issues.append(Issue(CHECK, ERROR, f'unknown backend service in dynamic method "{prefix}..."', rel, line, prefix))
        elif rel not in dynamic_allow:
            what = f'"{prefix}" + ...' if prefix else "non-literal method"
            issues.append(Issue(CHECK, WARN, f"dynamic backend method ({what}) cannot be checked; "
                                             "list the file in ipcMethods.dynamicAllow with a reason", rel, line, prefix))
    for line, name in found["subs"]:
        if name == "all":
            continue
        if name not in registry:
            issues.append(Issue(CHECK, ERROR, f'unknown backend service "{name}" in addSubscription', rel, line, name))
        elif not registry[name]["subscribe"]:
            issues.append(Issue(CHECK, ERROR, f'backend service "{name}" has no event stream (addSubscription)',
                                rel, line, name))
    for line in found["dynsubs"]:
        if rel not in dynamic_allow:
            issues.append(Issue(CHECK, WARN, "dynamic addSubscription services cannot be checked; "
                                             "list the file in ipcMethods.dynamicAllow with a reason", rel, line))
    return issues


def run(cfg: dict) -> list[Issue]:
    c = cfg.get("ipcMethods", {})
    if not REGISTRY.exists():
        return [Issue(CHECK, ERROR, "assets/schema/ipc-methods.json is missing: run `make schema`")]
    registry = load_registry()
    wrappers = c.get("wrappers", [])
    allow = {k: v for k, v in c.get("dynamicAllow", {}).items() if not k.startswith("_")}
    issues: list[Issue] = []
    seen_dynamic: set[str] = set()
    for rel in repo_files(".qml", ".js", exclude=("backend/", "tests/", "tools/", "docs/", "assets/")):
        text = (REPO / rel).read_text(errors="replace")
        if "BackendService" not in text and not any(re.search(w["pattern"], text) for w in wrappers):
            continue
        found = extract(rel, text, wrappers)
        if found["dynamic"] or found["dynsubs"]:
            seen_dynamic.add(rel)
        issues.extend(verify(rel, found, registry, allow))
    for rel, reason in allow.items():
        if not reason:
            issues.append(Issue(CHECK, ERROR, "ipcMethods.dynamicAllow entry without a reason", rel))
        elif rel not in seen_dynamic:
            issues.append(Issue(CHECK, WARN, "ipcMethods.dynamicAllow entry no longer matches a dynamic call", rel))
    return issues
