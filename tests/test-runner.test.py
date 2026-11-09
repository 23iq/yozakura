"""tools/lint/run_tests.py: shard split, run order and option parsing.

Pure Python (no Qt): the split must be deterministic and timing-balanced,
cover every test exactly once, and the order must put the slowest first.
"""
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "lint"))
import run_tests as rt  # noqa: E402

failures = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + (f" {detail}" if detail else ""))
    if not cond:
        failures.append(name)


tests = [Path(f"/x/{n}.test.py") for n in "abcdefghij"]
timings = {"a.test.py": 20.0, "b.test.py": 15.0, "c.test.py": 9.0, "d.test.py": 8.0, "e.test.py": 3.0,
           "f.test.py": 2.5, "g.test.py": 1.0, "h.test.py": 0.5}  # i, j unknown

# Shards: a partition, deterministic, balanced.
for n in (1, 2, 3, 4):
    parts = [rt.shard(tests, i, n, timings) for i in range(1, n + 1)]
    flat = sorted(p.name for part in parts for p in part)
    check(f"{n} shard(s) cover every test once", flat == sorted(p.name for p in tests))
    check(f"{n} shard(s) deterministic", parts == [rt.shard(list(reversed(tests)), i, n, timings) for i in range(1, n + 1)])
loads = [sum(timings.get(p.name, rt.UNKNOWN_WEIGHT) for p in rt.shard(tests, i, 2, timings)) for i in (1, 2)]
check("2 shards balanced", abs(loads[0] - loads[1]) <= 3.0, str(loads))
check("unknown tests are weighted", rt.shard(tests[:1], 1, 1, {}) == tests[:1])

# Order: unknown first, then longest first, ties alphabetical; local times fill gaps.
names = [p.name for p in rt.order(tests, timings, {"j.test.py": 5.0})]
check("unknown first", names[0] == "i.test.py", str(names))
check("longest first", names[1:4] == ["a.test.py", "b.test.py", "c.test.py"], str(names))
check("local time used for tests missing from the committed file", names.index("j.test.py") == names.index("e.test.py") - 1,
      str(names))

# Option parsing.
check("shard spec", rt.parse_shard("2/3") == (2, 3))
check("bad shard specs", all(rt.parse_shard(s) is None for s in ("0/2", "3/2", "x", "1/", "1/2/3")))
os.environ["YOZAKURA_TEST_JOBS"] = "3"
check("jobs from env, capped by the test count", rt.jobs_for(10) == 3 and rt.jobs_for(2) == 2)
os.environ["YOZAKURA_TEST_JOBS"] = "1"
check("JOBS=1 is serial", rt.jobs_for(50) == 1)
os.environ["YOZAKURA_TEST_JOBS"] = ""
check("default jobs >= 1", rt.jobs_for(50) >= 1)

# The committed timings file is valid and covers the current tests.
committed = rt.read_times(rt.TIMINGS)
check("tests/timings.json parses", bool(committed) and json.loads(rt.TIMINGS.read_text()) is not None)
missing = sorted(p.name for p in (REPO / "tests").glob("*.test.py") if p.name not in committed)
# New tests may land before the next `make test-timings`; only a large gap is an error.
check("tests/timings.json mostly current (make test-timings)", len(missing) <= 20, str(missing[:10]))

print("test-runner:", "PASS" if not failures else f"FAIL ({len(failures)})")
sys.exit(1 if failures else 0)
