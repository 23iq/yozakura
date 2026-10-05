#!/usr/bin/env python3
"""Project audit (knip-like): dead files, config schema, translations, monoliths.

Usage:
  audit.py                 human-readable report; exit 1 on errors
  audit.py --json          machine-readable report on stdout
  audit.py --only a,b      run a subset of checks
  audit.py --strict        treat warnings as errors
  audit.py --quiet         only print errors and the summary

Checks: dead-code, qs-scanner, brand-literals, shell-injection, config-keys, settings-schema, snapshot-keys, translations, monoliths.
Hard failures (severity "error"): shell/QML injection patterns, config schema mismatches, unknown config
keys used in code, missing translations. Warnings: dead files, snapshot
coverage, unused/stale translations, monoliths. Allowlists live in
tools/audit/config.json - every entry needs a reason.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from checks import (  # noqa: E402
    brand_literals,
    config_keys,
    dead_code,
    monoliths,
    qs_scanner,
    schema_fresh,
    settings_schema,
    shell_injection,
    snapshot_keys,
    translations,
)
from lib.model import ERROR, INFO, WARN, load_config  # noqa: E402

CHECKS = {m.CHECK: m for m in (config_keys, translations, brand_literals, dead_code, qs_scanner, shell_injection, settings_schema, schema_fresh, snapshot_keys, monoliths)}
_ICON = {ERROR: "[fail]", WARN: "[warn]", INFO: "[info]"}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    cfg = load_config()
    selected = [s for s in args.only.split(",") if s] or list(CHECKS)
    unknown = set(selected) - set(CHECKS)
    if unknown:
        ap.error(f"unknown check(s): {', '.join(sorted(unknown))}")
    issues = []
    for name in selected:
        issues.extend(CHECKS[name].run(cfg))
    if args.strict:
        for i in issues:
            if i.severity == WARN:
                i.severity = ERROR
    counts = Counter(i.severity for i in issues)

    if args.json:
        json.dump({"summary": {"errors": counts[ERROR], "warnings": counts[WARN], "info": counts[INFO]},
                   "issues": [i.to_dict() for i in issues]}, sys.stdout, indent=1)
        print()
    else:
        for name in selected:
            mine = [i for i in issues if i.check == name]
            shown = [i for i in mine if not args.quiet or i.severity == ERROR]
            sev = Counter(i.severity for i in mine)
            print(f"== {name}: {sev[ERROR]} error(s), {sev[WARN]} warning(s), {sev[INFO]} info")
            for i in shown:
                loc = f"{i.file}:{i.line}" if i.line else i.file
                print(f"  {_ICON[i.severity]} {loc + ': ' if loc else ''}{i.message}")
        if args.quiet and (counts[WARN] or counts[INFO]):
            print("  (warnings hidden; run `make audit` for the full report)")
        status = "FAILED" if counts[ERROR] else "passed"
        print(f"audit {status}: {counts[ERROR]} error(s), {counts[WARN]} warning(s), {counts[INFO]} info")
    return 1 if counts[ERROR] else 0


if __name__ == "__main__":
    sys.exit(main())
