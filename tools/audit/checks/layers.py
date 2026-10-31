"""Layer-direction audit: imports must point down the layer order, without cycles.

Order (config.json `layers`): foundation (theme, globals, components, config)
< services < features (every other modules/<X>/) < shell (modules/shell and the
root entry files). A module may import its own layer or a lower one; importing
a higher layer is an "upward" import. Modules that import each other (directly
or through a chain) form a cycle.

The graph comes from `import qs.modules.<X>` / `import qs.config` lines (QML
`import` and JS `.import`; comments ignored). Violations that exist today are
recorded in tools/lint/baselines/layers.json (a ratchet): only NEW violations
fail. Upward imports are counted per module pair; cycles are module pairs that import
each other directly (the whole graph is one big strongly connected component,
reported as info, which a ratchet cannot guard). Fixing old ones lowers the numbers; the audit
then asks to refresh the baseline (`make layers-baseline`), never to silence
new findings.
"""
from __future__ import annotations

import json
import os
import re

from lib.model import ERROR, INFO, REPO, WARN, Issue, repo_files
from lib.qmlscan import scan_text

CHECK = "layers"
BASELINE = REPO / "tools" / "lint" / "baselines" / "layers.json"
ROOT_NODE = "(root)"
_IMPORT = re.compile(r"^\s*\.?import\s+qs((?:\.\w+)+)", re.M)

DEFAULT_LAYERS = [
    ["theme", "globals", "components", "config"],
    ["services"],
    ["*"],
    ["shell", ROOT_NODE],
]


def module_of(import_path: str) -> str | None:
    """`.modules.bar.panels` -> bar; `.config.adapters` -> config; others -> None."""
    parts = [p for p in import_path.split(".") if p]
    if parts[:1] == ["config"]:
        return "config"
    if parts[:1] == ["modules"] and len(parts) > 1:
        return parts[1]
    return None


def file_node(rel: str) -> str:
    parts = rel.split("/")
    if parts[0] == "modules" and len(parts) > 2:
        return parts[1]
    if parts[0] == "config":
        return "config"
    return ROOT_NODE


def layer_index(node: str, layers: list[list[str]]) -> int:
    wildcard = -1
    for i, group in enumerate(layers):
        if node in group:
            return i
        if "*" in group:
            wildcard = i
    return wildcard


def build_edges(sources: dict[str, str]) -> dict[tuple[str, str], list[str]]:
    """{(from_module, to_module): [importing files]} for cross-module imports."""
    edges: dict[tuple[str, str], set[str]] = {}
    for rel, text in sources.items():
        src = file_node(rel)
        for m in _IMPORT.finditer(scan_text(text).code):
            dst = module_of(m.group(1))
            if dst and dst != src:
                edges.setdefault((src, dst), set()).add(rel)
    return {k: sorted(v) for k, v in edges.items()}


def find_cycles(edges: dict[tuple[str, str], list[str]]) -> list[list[str]]:
    """Strongly connected components with more than one module (Tarjan)."""
    graph: dict[str, list[str]] = {}
    for a, b in edges:
        graph.setdefault(a, []).append(b)
        graph.setdefault(b, [])
    index: dict[str, int] = {}
    low: dict[str, int] = {}
    stack: list[str] = []
    on: set[str] = set()
    out: list[list[str]] = []
    counter = [0]

    def visit(v: str) -> None:
        index[v] = low[v] = counter[0]
        counter[0] += 1
        stack.append(v)
        on.add(v)
        for w in sorted(graph[v]):
            if w not in index:
                visit(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                on.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                out.append(sorted(comp))

    for v in sorted(graph):
        if v not in index:
            visit(v)
    return sorted(out)


def mutual_pairs(edges: dict[tuple[str, str], list[str]]) -> list[list[str]]:
    """Module pairs that import each other directly (the smallest cycles)."""
    return sorted([a, b] for (a, b) in edges if a < b and (b, a) in edges)


def analyze(sources: dict[str, str], layers: list[list[str]]) -> dict:
    edges = build_edges(sources)
    upward = {}
    for (a, b), files in edges.items():
        if layer_index(a, layers) < layer_index(b, layers):
            upward[f"{a} -> {b}"] = len(files)
    return {"upward": dict(sorted(upward.items())), "cycles": mutual_pairs(edges),
            "components": find_cycles(edges), "edges": edges}


def compare(current: dict, baseline: dict) -> tuple[list[str], list[str]]:
    """(new violations, baseline entries that improved) as messages."""
    new, better = [], []
    base_up = baseline.get("upward", {})
    for pair, n in current["upward"].items():
        if pair not in base_up:
            new.append(f"new upward import {pair} ({n} file(s))")
        elif n > base_up[pair]:
            new.append(f"more upward imports {pair}: {n} > baseline {base_up[pair]}")
    for pair, n in base_up.items():
        if current["upward"].get(pair, 0) < n:
            better.append(f"{pair}: {current['upward'].get(pair, 0)} < baseline {n}")
    for cyc in current["cycles"]:
        if cyc not in baseline.get("cycles", []):
            new.append(f"new import cycle {' <-> '.join(cyc)}")
    for b in baseline.get("cycles", []):
        if b not in current["cycles"]:
            better.append(f"cycle {' <-> '.join(b)} is gone")
    return new, better


def _sources() -> dict[str, str]:
    files = repo_files(".qml", ".js", exclude=("backend/", "tests/", "tools/", "docs/", "assets/"))
    keep = [f for f in files if f == "shell.qml" or f.startswith(("modules/", "config/"))
            or "/" not in f]
    return {f: (REPO / f).read_text(errors="replace") for f in keep}


def run(cfg: dict) -> list[Issue]:
    layers = cfg.get("layers", {}).get("order", DEFAULT_LAYERS)
    result = analyze(_sources(), layers)
    snapshot = {"upward": result["upward"], "cycles": result["cycles"]}
    if os.environ.get("AUDIT_UPDATE_LAYERS"):
        BASELINE.write_text(json.dumps(snapshot, indent=1) + "\n")
        return [Issue(CHECK, INFO, f"wrote {BASELINE.relative_to(REPO)}")]
    baseline = json.loads(BASELINE.read_text()) if BASELINE.exists() else {"upward": {}, "cycles": []}
    new, better = compare(result, baseline)
    issues = [Issue(CHECK, ERROR, m + " (see AGENTS.md, Quality tooling: layers)") for m in new]
    issues += [Issue(CHECK, WARN, f"improved, refresh the baseline with `make layers-baseline`: {m}") for m in better]
    n_up = sum(result["upward"].values())
    issues.append(Issue(CHECK, INFO, f"{n_up} upward import(s) in {len(result['upward'])} module pair(s), "
                                     f"{len(result['cycles'])} mutual import pair(s) (baselined); "
                                     f"{max((len(c) for c in result['components']), default=0)} modules form one "
                                     f"strongly connected component"))
    return issues
