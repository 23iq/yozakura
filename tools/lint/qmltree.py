"""Build a qmllint-friendly mirror of the shell so `import qs.*` resolves.

Quickshell serves the shell directory as the virtual module root `qs`
(`import qs.modules.theme` -> <shell>/modules/theme) and synthesises qmldir
files at runtime. qmllint knows nothing about that VFS, so we recreate it:

  .cache/lint/qmltree/qs/<same layout as the repo>   (symlinks to the sources)
  .cache/lint/qmltree/qs/<dir>/qmldir                (generated: module qs.<dir>,
                                                     singletons from `pragma Singleton`)

Quickshell's own types come from /usr/lib/qt6/qml/Quickshell (qmltypes).

Lint-only shadowing (the real sources are never modified): Quickshell's
JsonAdapter subclasses are exposed as `property QtObject theme: loader.adapter`,
which erases their type, so every `Config.bar.foo` would be reported as missing.
In the mirror, files using `adapter: JsonAdapter {` get a copy where:
  * the inline adapter gets an id and `property QtObject x: <loader>.adapter`
    becomes `property alias x: <that id>`, so qmllint sees the real keys and
    flags typos/unknown config keys (`Config.bar.nonexistent`);
  * nested `property JsonObject x: JsonObject {` become `property var x:`
    (qmllint cannot type inline objects; `var` keeps them unchecked, not noisy),
    also in the generated adapter components (config/adapters/*.qml, root
    `JsonAdapter {`), which Config.qml exposes as typed properties.
All edits stay on the same line, so reported line numbers match the sources.
"""
from __future__ import annotations

import os
import re
import shutil
from pathlib import Path

from common import CACHE, REPO, git

TREE = CACHE / "qmltree"
ROOT = TREE / "qs"
# Directories never needed for QML resolution (huge or unrelated).
SKIP_PREFIXES = ("backend/", "nix/", ".github/", "docs/", "examples/", "tests/", "tools/")

_SINGLETON = re.compile(r"^\s*pragma\s+Singleton\b", re.M)
_ADAPTER = re.compile(r"^(\s*adapter:\s*JsonAdapter\s*\{)\s*$")
_ID = re.compile(r"^\s*id:\s*(\w+)\s*;?\s*$")
_TYPED_ALIAS = re.compile(r"^(\s*)(readonly\s+)?property\s+QtObject\s+(\w+):\s*(\w+)\.adapter\s*$")
_ADAPTER_ROOT = re.compile(r"^JsonAdapter\s*\{", re.M)  # config/adapters/*.qml
_NESTED = re.compile(r"^(\s*)property\s+JsonObject\s+(\w+):\s*JsonObject\s*\{")


def _source_files() -> list[str]:
    out = git("ls-files", "--cached", "--others", "--exclude-standard")
    return [f for f in out.splitlines() if f and not f.startswith(SKIP_PREFIXES) and (REPO / f).is_file()]


def shadow_adapters(src: str) -> str:
    """Return a lint-only variant of a file with typed JsonAdapter aliases."""
    lines = src.split("\n")
    last_id = None
    adapters: set[str] = set()
    for i, line in enumerate(lines):
        m = _ID.match(line)
        if m:
            last_id = m.group(1)
        if _ADAPTER.match(line) and last_id:
            lines[i] = line.rstrip() + f" id: {last_id}__lintAdapter;"
            adapters.add(last_id)
    for i, line in enumerate(lines):
        m = _TYPED_ALIAS.match(line)
        if m and m.group(4) in adapters:
            lines[i] = f"{m.group(1)}{m.group(2) or ''}property alias {m.group(3)}: {m.group(4)}__lintAdapter"
            continue
        m = _NESTED.match(line)
        if m:
            lines[i] = _NESTED.sub(r"\1property var \2: JsonObject {", line, count=1)
    return "\n".join(lines)


def build() -> Path:
    """(Re)build the mirror and return the directory to pass as `-I`."""
    if TREE.exists():
        shutil.rmtree(TREE)
    qml_by_dir: dict[Path, list[tuple[str, bool]]] = {}
    for rel in _source_files():
        src = REPO / rel
        dst = ROOT / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        if rel.endswith(".qml"):
            text = src.read_text(errors="replace")
            if "adapter: JsonAdapter" in text or _ADAPTER_ROOT.search(text):
                dst.write_text(shadow_adapters(text))
            else:
                os.symlink(src, dst)
            name = Path(rel).stem
            if name[:1].isupper():
                qml_by_dir.setdefault(dst.parent, []).append((name, bool(_SINGLETON.search(text[:4000]))))
        else:
            os.symlink(src, dst)
    for d, types in qml_by_dir.items():
        rel = d.relative_to(ROOT)
        module = ".".join(("qs", *rel.parts))
        body = [f"module {module}"]
        body += [f"{'singleton ' if s else ''}{n} 1.0 {n}.qml" for n, s in sorted(types)]
        (d / "qmldir").write_text("\n".join(body) + "\n")
    return TREE


if __name__ == "__main__":
    print(build())
