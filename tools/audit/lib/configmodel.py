"""Read the config domain adapters and config/defaults/*.js into comparable trees.

Config.qml declares one `ConfigFile { id: <loader>; name: "<domain>";
defaults: <Alias>.data; adapter: <Name>Adapter {} }` per domain; the adapter
component lives in config/adapters/<Name>Adapter.qml (generated from the
defaults by tools/config/gen_adapters.cjs).

A tree is {key: subtree | None}; None marks a leaf. Only `JsonObject`
children are descended into on the QML side: a `property var x: ({...})`
holds free-form JSON, so its inner keys are not part of the schema.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from functools import cache

from lib.model import REPO, eval_js_data
from lib.qmlscan import find_block_end, scan_file

CONFIG_QML = REPO / "config" / "Config.qml"
PROP = re.compile(r"\b(?:readonly\s+|required\s+|default\s+)*property\s+([\w.<>]+)\s+(\w+)")
CONFIG_FILE = re.compile(r"\bConfigFile\s*\{")
ADAPTERS = REPO / "config" / "adapters"
JS_IMPORT = re.compile(r'^\s*import\s+"([^"]+\.js)"\s+as\s+(\w+)', re.M)
ALIAS = re.compile(r"^\s*(?:readonly\s+)?property\s+\w+\s+(\w+):\s*(\w+)\.adapter\s*$", re.M)


@dataclass
class Domain:
    name: str  # validateModule name, e.g. "bar"
    loader: str  # FileView id, e.g. "barLoader"
    defaults_file: str  # repo-relative path of the defaults JS
    adapter: dict = field(default_factory=dict)  # tree from the adapter component
    adapter_file: str = "config/Config.qml"  # repo-relative file declaring the adapter
    adapter_line: int = 0
    defaults: dict | None = None  # tree from defaults JS (None = node missing)


def _depths(code: str) -> list[int]:
    out, d = [0] * (len(code) + 1), 0
    for i, ch in enumerate(code):
        out[i] = d
        if ch == "{":
            d += 1
        elif ch == "}":
            d -= 1
    return out


def parse_object(code: str, depths: list[int], open_idx: int) -> dict:
    """Properties declared directly inside the object whose `{` is at open_idx."""
    end = find_block_end(code, open_idx)
    inner = depths[open_idx] + 1
    tree: dict = {}
    for m in PROP.finditer(code, open_idx, end):
        if depths[m.start()] != inner:
            continue
        ptype, name = m.group(1), m.group(2)
        child = None
        if ptype == "JsonObject":
            jm = re.compile(r"\s*:\s*JsonObject\s*\{").match(code, m.end())
            if jm:
                child = parse_object(code, depths, jm.end() - 1)
        tree[name] = child
    return tree


def to_tree(value: object) -> dict | None:
    if isinstance(value, dict):
        return {k: to_tree(v) for k, v in value.items()}
    return None


def _adapter_component(name: str) -> tuple[dict, int] | None:
    path = ADAPTERS / f"{name}.qml"
    if not path.exists():
        return None
    code = scan_file(path).code
    m = re.search(r"^JsonAdapter\s*\{", code, re.M)
    if not m:
        return None
    return parse_object(code, _depths(code), m.end() - 1), code.count("\n", 0, m.start()) + 1


@cache
def load() -> tuple[list[Domain], dict[str, str]]:
    """Return (domains, {Config property name: domain name})."""
    raw = CONFIG_QML.read_text()
    scan = scan_file(CONFIG_QML)
    js_alias = {alias: path for path, alias in JS_IMPORT.findall(raw)}
    domains: list[Domain] = []
    seen = set()
    for m in CONFIG_FILE.finditer(scan.code):
        block = raw[m.end():find_block_end(scan.code, m.end() - 1)]
        loader = re.search(r"\bid:\s*(\w+)", block)
        name = re.search(r'\bname:\s*"(\w+)"', block)
        alias = re.search(r"\bdefaults:\s*(\w+)\.data\b", block)
        comp = re.search(r"\badapter:\s*(\w+)\s*\{", block)
        if not (loader and name and alias) or name.group(1) in seen or alias.group(1) not in js_alias:
            continue
        seen.add(name.group(1))
        d = Domain(name.group(1), loader.group(1), f"config/{js_alias[alias.group(1)]}")
        parsed = _adapter_component(comp.group(1)) if comp else None
        if parsed:
            d.adapter, d.adapter_line = parsed
            d.adapter_file = f"config/adapters/{comp.group(1)}.qml"
        domains.append(d)
    data = eval_js_data([REPO / d.defaults_file for d in domains])
    if data is not None:
        for d in domains:
            d.defaults = to_tree(data.get(str(REPO / d.defaults_file)) or {})
    loader_to_domain = {d.loader: d.name for d in domains}
    props = {prop: loader_to_domain[ld] for prop, ld in ALIAS.findall(raw) if ld in loader_to_domain}
    return domains, props


def flatten(tree: dict | None, prefix: str = "") -> dict[str, dict | None]:
    out: dict[str, dict | None] = {}
    for k, v in (tree or {}).items():
        out[prefix + k] = v
        if v:
            out.update(flatten(v, f"{prefix}{k}."))
    return out
