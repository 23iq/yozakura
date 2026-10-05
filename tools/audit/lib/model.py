"""Shared types and repo access for audit checks."""
from __future__ import annotations

import json
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CONFIG_PATH = REPO / "tools" / "audit" / "config.json"

ERROR, WARN, INFO = "error", "warn", "info"


@dataclass
class Issue:
    check: str
    severity: str  # error | warn | info
    message: str
    file: str = ""
    line: int = 0
    key: str = ""  # stable identifier used by allowlists (e.g. "bar.position")

    def to_dict(self) -> dict:
        return {k: v for k, v in asdict(self).items() if v not in ("", 0)}


def load_config() -> dict:
    return json.loads(CONFIG_PATH.read_text()) if CONFIG_PATH.exists() else {}


def repo_files(*suffixes: str, exclude: tuple[str, ...] = ("backend/", "tests/", "tools/")) -> list[str]:
    """Tracked + untracked (non-ignored) files with the given suffixes."""
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                         cwd=REPO, capture_output=True, text=True, check=True).stdout
    return sorted(f for f in set(out.splitlines())
                  if f.endswith(suffixes) and not f.startswith(exclude) and (REPO / f).is_file())


def eval_js_data(paths: list[Path]) -> dict[str, object] | None:
    """Evaluate `.pragma library` JS files and return {path: data}. None if node is missing."""
    script = r"""
const fs = require('fs'), vm = require('vm'); const out = {};
for (const f of process.argv.slice(1)) {
  const src = fs.readFileSync(f, 'utf8').replace(/^\s*\.(pragma|import)\b.*$/gm, '');
  const ctx = {}; vm.createContext(ctx); vm.runInContext(src, ctx, { filename: f });
  out[f] = ctx.data;
}
process.stdout.write(JSON.stringify(out));
"""
    try:
        r = subprocess.run(["node", "-e", script, *map(str, paths)], cwd=REPO, capture_output=True, text=True)
    except FileNotFoundError:
        return None
    if r.returncode:
        raise RuntimeError(f"evaluating defaults failed: {r.stderr.strip()[:500]}")
    return json.loads(r.stdout)
