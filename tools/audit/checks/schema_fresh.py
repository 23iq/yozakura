"""The generated settings catalog (assets/schema/*.schema.json) and the
generated config adapters (config/adapters/*.qml) are up to date.

It is built by tools/schema/gen_schema.cjs from config/defaults/*.js, the
settings schema (modules/settings/schema/*.js), config/meta/*.js and
translations/en.json; `yozakura config` and the MCP config tools read it at
runtime. Any change to those sources needs `make schema`. Generator errors
(a config/meta path that matches no key, a default outside its enum/range)
are reported too. The adapters are built by tools/config/gen_adapters.cjs from
config/defaults/*.js, config/meta/AdapterTypes.js and config/CoreBinds.js.
"""
from __future__ import annotations

import shutil
import subprocess

from lib.model import ERROR, REPO, Issue

CHECK = "schema-fresh"
GENS = ("tools/schema/gen_schema.cjs", "tools/config/gen_adapters.cjs")


def run(cfg: dict) -> list[Issue]:
    if not shutil.which("node"):
        return []
    return [i for gen in GENS for i in _check(gen)]


def _check(gen: str) -> list[Issue]:
    what = "config adapter" if "adapters" in gen else "catalog"
    r = subprocess.run(["node", str(REPO / gen), "--check"], capture_output=True, text=True)
    if r.returncode == 0:
        return []
    issues: list[Issue] = []
    for line in (r.stdout + r.stderr).splitlines():
        line = line.strip()
        if line.startswith(("stale: ", "extra: ")):
            path = line.split(": ", 1)[1]
            issues.append(Issue(CHECK, ERROR, f"{line.split(':')[0]} generated {what}; run `make schema`",
                                file=path, key=path))
        elif line.startswith("error: "):
            msg = line[len("error: "):]
            issues.append(Issue(CHECK, ERROR, msg, file="config/meta", key=msg))
    if not issues:
        issues.append(Issue(CHECK, ERROR, f"{gen} --check failed: {(r.stderr or r.stdout).strip()[-400:]}", file=gen))
    return issues
