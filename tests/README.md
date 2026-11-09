# Tests

Run everything with `make test` (or `make check` for the full gate).

| Kind | Files | Runner |
|------|-------|--------|
| Pure JS logic (`modules/**/*.js`) | `*.test.cjs` | `node --test tests/` |
| QML behaviour, offscreen | `*.test.py` | `python3 tests/<name>.test.py` (needs PySide6) |
| Go backend | `backend/**/*_test.go` | `cd backend && go test ./...` |

Every `*.test.py` is run as a script; a non-zero exit code is a failure.

## Parallel runs, shards, timings

`tools/lint/run_tests.py` runs the Python tests in parallel (each in its own
process group), the slowest first, and prints each result as it finishes:

| Make / env | Effect |
|------------|--------|
| `JOBS=N` / `YOZAKURA_TEST_JOBS` | workers (default: CPU count; `JOBS=1` = serial, for debugging) |
| `SHARD=i/N` / `YOZAKURA_TEST_SHARD` | only shard `i` of `N`; greedy bin packing over `tests/timings.json`, the same split on every machine |
| `YOZAKURA_TEST_RETRY=1` | re-run failed tests once, serially; a pass is reported as `flaky (passed on retry)` and does not fail (CI sets it) |
| `YOZAKURA_TEST_TIMEOUT` | in-test watchdog (`headless.py`), default 45 s |
| `YOZAKURA_TEST_HARD_TIMEOUT` | runner kill timeout per test, default 90 s |

`tests/timings.json` holds seconds per test file; `make test-timings` re-runs
the suite and rewrites it (do it when you add a slow test; a missing entry
just runs first and weighs 2 s in the shard split). Each run also caches
this machine's times in `.cache/test-py-times.json`.

Tests run side by side, so a test must never write to a fixed shared path
(`/tmp/foo.png`, a fixed home): use the harness temp dir (`h.root`), and
`qmlharness.HARNESS_HOME` (the runner sets `YOZAKURA_HARNESS_HOME` to a fresh
directory per test; default `/tmp/qmlharness-home`). Debug output files go
behind an env var (`AI_WORKSPACE_SHOTS=<dir>`, `DEPTH_VIDEO_FRAMES=<dir>`).

## Writing a QML test: `tests/lib/qmlharness.py`

Do not hand-copy files and hand-write qmldir files (that is how tests broke
whenever a component gained a new import or a new child type). Use the harness:

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("my-feature")
# Stub only what the test reads; bodies may omit `import QtQuick` / `pragma Singleton`.
h.singleton("qs.config", "Config", "QtObject { property QtObject notch: QtObject { property int delay: 30 } }")
h.module("Quickshell.Io", {"Process": "QtObject { property var command; property bool running }"})

view = h.copy("modules/lockscreen/LockView.qml")   # + relative JS/qsb/sibling QML it uses
root = h.load('Item { width: 800; height: 600; LockView { objectName: "lv" } }')
lv = h.find(root, "lv")
assert h.eval(lv, "passwordPill.hint") == ""
```

- `copy(path, strip_singleton=..., siblings=..., replace={...})` copies a repo file
  and, recursively, everything it references relatively: `import "X.js"`,
  `.import` inside JS, `import "./Y.qml"`, sibling types from the same directory
  and string literals naming existing files (`*.qsb` shaders, sounds, ...).
  `siblings=False` when you want to stub the children yourself (`h.stub(...)`).
- `load(path_or_inline_qml)` auto-stubs unknown types (`X is not a type`), the
  properties/signal handlers assigned on those stubs, and missing modules, and
  prints each auto-stub to stderr. Use `auto_stub=False` for strict tests.
- Keep the object returned by `load()`; read `h.engine` after `load()`.
- `QML_HARNESS_KEEP=1` keeps the temp tree for debugging.

`palette-crossfade.test.py` and `qmlharness.test.py` use the harness; the
older tests still build their stubs by hand and can be migrated when touched.

## Headless by construction: `tests/lib/headless.py`

QML tests must never open a window on the live desktop. Import
`tests/lib/headless.py` (the harness does) before PySide6: it drops
`WAYLAND_DISPLAY`/`DISPLAY` and forces `QT_QPA_PLATFORM=offscreen`. Tests
that need GL (video, shader effects) call `headless.ensure(gl=True)`, which
re-runs the test under a private `Xvfb -displayfd` with xcb (never
`xvfb-run -a`: it guesses a display number and races with other runs); an
inherited display (Xwayland `:0`) is never used. `tools/check.sh` and
`run_tests.py` also strip the display variables.

Timeouts: importing `headless` arms a watchdog that dumps every thread's
stack and exits after `YOZAKURA_TEST_TIMEOUT` seconds (default 45; the
slowest passing test takes ~20 s); `run_tests.py` runs each test in its own
process group and kills the group after `YOZAKURA_TEST_HARD_TIMEOUT`
(default 90). Tests that play media end
with `h.exit(code)` (harness) so Qt Multimedia is never torn down from the
interpreter's exit path.

The harness fails loudly when a type that exists as a `.qml` file in the repo
would be auto-stubbed, and exits non-zero if any "X is not a type" / "Type X
unavailable" warning shows up at runtime (Loader, `layer.effect`).
Quickshell-only resolution problems (directories its scanner never reaches)
are caught by the `qs-scanner` audit check.


## Waiting: `tests/lib/waits.py`

Wait for a state, not for a clock: `wait_until(lambda: h.eval(o, "ready"))`
returns as soon as the predicate holds (an exception counts as "not yet"),
with a timeout generous enough for a loaded CI machine (scaled by
`YOZAKURA_TEST_WAIT_SCALE`), and prints where it timed out. `wait_stable(fn)`
waits until a value (a position, a scroll) stops changing, e.g. before a
click on an item that may still be sliding in. `settle()` flushes
`Qt.callLater`, 0 ms timers and a couple of frames (enough with
`animDuration: 0`). Keep `pump(ms)` for waits that deliberately let time pass
(a debounce, "nothing may happen"), and shorten the interval in the test when
it is exposed (`writeDebounce.interval`, a `replace=` on `h.copy`) rather than
waiting the real duration. Do not define a local `pump`.

## Bar panels: `tests/lib/panels_env.py`

`PanelsEnv(bar=..., theme=..., palette=...)` mirrors the real bar, panel
styles, modules, frame and notch and stubs the services with a fixture
desktop (`panels_stubs.py`: workspaces, windows, tray, battery, weather,
downloads...). `env.scene(w, h)` loads a whole screen; `tests/panels.test.py`
uses it, `tools/render/panels_render.py` renders layouts to PNG (dark/light,
`--sheet` contact sheet, `--repo` for before/after pixel comparisons,
`"actions"` to hover/open popups).
