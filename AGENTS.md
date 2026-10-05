# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-01
**Framework:** QtQuick / Quickshell
**Language:** QML / JavaScript

## AI AGENTS: START HERE
`docs/ai-guide.md` is the task-oriented map: project layout, the `yozakura
config` / `yozakura preset` CLI and the `yozakura mcp` tools (search,
describe, get, set, presets), 40+ "how do I" recipes, where each feature's
code lives and how to add a setting/module/panel/preset/clock style.
`llms.txt` is the short index. Change settings through the CLI/MCP (they
validate against the generated catalog `assets/schema/*.schema.json`), never
by guessing keys. After touching `config/defaults`, `config/meta` or
`modules/settings/schema`, run `make schema`.

## COMPOSITOR DAEMON: yozd

`yozd` (the compositor abstraction: one JSON API over Hyprland/niri/MangoWC,
idle monitors, brightness, compositor config generation) is our own code in
`backend/cmd/yozd` + `backend/pkg/yozd/` (see `backend/pkg/yozd/AGENTS.md`).
It is derived from an upstream project (AGPL-3.0, credited in `NOTICE`). The backend
supervises it; `make build` builds both binaries. Its name lives in
`brand.Daemon` / `Brand.daemon` / `BRAND_DAEMON` only: binary, socket, config
file (`~/.local/share/yozakura/yozd.toml`), env vars and log prefixes derive
from it. The shell runs `Brand.daemonBin` (exported by the backend), never a
literal name.

## IDENTITY
History: Yozakura started as a fork of Ambxst (AGPL-3.0, see `NOTICE`); refer
to it as Yozakura everywhere else. The app identity lives in one place per language:
`backend/pkg/brand`, `modules/globals/Brand.qml` + `BrandActions.js`,
`scripts/lib/brand.{sh,py}`. Never hard-code the app id, its dirs, env prefix,
namespaces or action ids; the `brand-literals` audit fails on the legacy name
outside legal files, the README credits line, migration (`backend/pkg/migrate`)
and legacy-compat code.

## OVERVIEW
Yozakura is a highly customizable Wayland shell built with Quickshell. It provides a unified panel (bar, dock, notch), dashboard, lockscreen, desktop widgets, and notification system, driven by a reactive JSON configuration system. Multi-monitor support via `Variants` on `Quickshell.screens`.

## STRUCTURE
```
./
├── config/               # Config singleton + JSON defaults (see config/AGENTS.md)
│   └── defaults/*.js     # Blueprint for each config domain (bar, theme, ai, etc.)
├── modules/
│   ├── bar/              # Panel widgets: clock, systray, workspaces, indicators
│   ├── components/       # Reusable UI primitives + GLSL shaders (55 files)
│   ├── corners/          # Rounded screen corners overlay
│   ├── desktop/          # Desktop background + icon grid
│   ├── dock/             # App dock (standalone or integrated into bar)
│   ├── frame/            # Screen border/glow effect
│   ├── globals/          # GlobalStates.qml — transient runtime state
│   ├── keybinds/         # binds.json model (BindModel/KeyNames), KeybindsStore, cheatsheet overlay
│   ├── lockscreen/       # WlSessionLock + PAM authentication
│   ├── notch/            # Dynamic island UI (launcher, dashboard, notifications)
│   ├── notifications/    # Notification popup system + history
│   ├── onboarding/       # First-run setup wizard: step registry, preset gallery, keybind tour
│   ├── services/         # Backend singletons (30+): Battery, AI, Network, etc.
│   ├── settings/         # Schema-driven settings window (see modules/settings/AGENTS.md)
│   ├── shell/            # UnifiedShellPanel + ReservationWindows + OSD
│   ├── theme/            # Colors, Icons, Styling singletons + app generators
│   ├── tools/            # Screenshot, screen recording, mirror, color picker
│   └── widgets/          # Complex overlays: dashboard, launcher, overview, etc.
│       ├── config/       # AiPanel (hosted by the settings window)
│       ├── dashboard/    # Main hub: controls, metrics, assistant, clipboard, notes
│       ├── defaultview/  # Notch idle content (compact player, notification indicator)
│       ├── launcher/     # App search + multi-tab launcher
│       ├── overview/     # Mission Control workspace overview
│       ├── powermenu/    # Lock, logout, shutdown actions
│       ├── presets/      # Theme/layout preset switcher
│       └── tools/        # Quick utility access (OCR, recording, etc.)
├── assets/               # Wallpapers, color presets, AI provider configs, sounds
├── scripts/              # Residual Python/Bash helpers (most logic in backend/)
├── backend/              # Go backend — single `yozakura` process supervises Quickshell, yozd and wl-paste (replaces cli.sh)
├── nix/                  # Nix flake, packages, and module definitions
├── shell.qml             # Entry point: ShellRoot, Variants, service init
└── cli.sh                # REMOVED — replaced by Go binary `yozakura`
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Entry Point** | `shell.qml` | `ShellRoot` → `Variants` per screen for each layer |
| **Config Logic** | `config/Config.qml` | One `ConfigFile` (FileView) per domain + generated `config/adapters/*Adapter.qml` |
| **Transient State** | `modules/globals/GlobalStates.qml` | Window visibility, active modes, runtime flags |
| **Services** | `modules/services/*.qml` | 30+ singletons. System integration layer |
| **Theme/Colors** | `modules/theme/Colors.qml` | Watches `~/.cache/yozakura/colors.json` reactively |
| **Styling** | `modules/theme/Styling.qml` | `radius()`, `fontSize()`, `getStyledRectConfig()` |
| **UI Primitives** | `modules/components/` | `StyledRect`, `BarPopup`, `SearchInput`, shaders |
| **Dashboard** | `modules/widgets/dashboard/` | Tabbed hub with LRU lazy-loading |
| **Launcher** | `modules/widgets/launcher/` | Provider search (apps, calculator/units/currency, commands, files, wallpapers, ask AI) + prefix tabs; see its AGENTS.md |
| **Bar Layout** | `modules/bar/BarContent.qml` | Auto-hide, horizontal/vertical, widget groups |
| **Notch** | `modules/notch/Notch.qml` | Dynamic island with StackView navigation |
| **Overview** | `modules/widgets/overview/` | Mission Control workspace view |
| **Lockscreen** | `modules/lockscreen/LockScreen.qml` | PAM auth + `WlSessionLockSurface` |
| **Notifications** | `modules/notifications/` | Popup system + delegate + history |
| **Adding Config** | `config/defaults/*.js` + `make schema` | Adapters are generated; int/var keys: `config/meta/AdapterTypes.js` |
| **Onboarding** | `modules/onboarding/`, `modules/services/OnboardingService.qml` | First-run wizard; steps in `OnboardingSteps.js`; `general.onboardingDone`; `<app> run onboarding` |
| **Keybinds** | `config/CoreBinds.js`, `config/KeybindActions.js`, `modules/keybinds/` | Core bind registry, action catalog (group + `binds.action.*` label), cheatsheet; editor in `modules/settings/editors/Keybind*` |
| **Settings UI** | `modules/settings/schema/*.js` | Declare a setting (one entry + translations); see `modules/settings/AGENTS.md` |
| **Settings catalog** | `config/meta/*.js` + `tools/schema/` -> `assets/schema/` | Descriptions/enums/ranges of keys the settings UI does not declare; `make schema`; read by `backend/pkg/catalog` (CLI + MCP) |
| **Config CLI / MCP** | `backend/cmd/yozakura/cmds_config.go`, `cmds_preset.go`, `backend/pkg/mcp/yozakura/` | `yozakura config ...`, `yozakura preset ...`, `yozakura mcp` |

## CODE MAP

| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `Config` | Singleton | `config/Config.qml` | Central config store. Reactive to JSON file changes |
| `GlobalStates` | Singleton | `modules/globals/GlobalStates.qml` | Shared runtime state (non-persistent) |
| `Visibilities` | Singleton | `modules/services/Visibilities.qml` | UI visibility/layering manager per screen |
| `Colors` | Singleton | `modules/theme/Colors.qml` | Dynamic color palette from JSON |
| `Styling` | Singleton | `modules/theme/Styling.qml` | Shared style utilities (radius, font, variants) |
| `Icons` | Singleton | `modules/theme/Icons.qml` | Phosphor-Bold icon font character map |
| `StyledRect` | Component | `modules/components/StyledRect.qml` | Base themed container (300+ usages) |
| `GradientCache` | Singleton | `modules/components/GradientCache.qml` | GPU texture sharing optimization |
| `UnifiedShellPanel` | Component | `modules/shell/UnifiedShellPanel.qml` | Full-screen `PanelWindow` for Bar + Notch + Dock |
| `ShellRoot` | Component | `shell.qml` | Root window. `Variants` per screen |
| `YozdService` | Singleton | `modules/services/YozdService.qml` | Compositor abstraction; state sourced via IPC subscription to the backend `compositor` service |
| `BackendService` | Singleton | `modules/services/BackendService.qml` | JSON-RPC client + subscription manager for the yozakura daemon |
| `StateService` | Singleton | `modules/services/StateService.qml` | JSON persistence for session state |
| `FocusGrabManager` | Singleton | `modules/services/FocusGrabManager.qml` | Input focus coordination |

## CONVENTIONS
- **Singletons**: `pragma Singleton` + `Singleton { id: root }` for all services and global state.
- **Imports**: `import qs.modules.*` namespace. Resolved by Quickshell's module system, not `qmldir` files (`make lint-qml` generates throwaway qmldirs in `.cache/` for qmllint).
- **Persistence**: `FileView` watches JSON on disk; `JsonAdapter` creates bidirectional QML bindings.
- **Formatting**: 4-space indent.
- **Defaults**: New config keys MUST have entries in `config/defaults/*.js`.
- **Multi-monitor**: `Variants { model: Quickshell.screens }` pattern for per-screen instances.
- **StyledRect variants**: Use `"pane"`, `"popup"`, `"common"`, `"internalbg"`, `"focus"` for containers.
- **Null safety**: Always null-check nested properties in QML to avoid `TypeError: Value is undefined`.
- **Bulk config**: Use `root.pauseAutoSave` when updating multiple Config properties at once.
- **Service init**: Critical services init on next tick via `Qt.callLater`; non-critical deferred 2s (see `shell.qml:280-302`).
- **Async safety**: Use `Qt.callLater()` when modifying lists inside process handlers.

## ANTI-PATTERNS (THIS PROJECT)
- **Hardcoding**: NEVER hardcode colors/sizes. Use `Config.theme.*`, `Config.bar.*`, `Colors.*`, `Styling.*`.
- **Direct Config Props**: AVOID modifying `Config` properties directly; they are bound to `JsonAdapter`.
- **Global Pollution**: Do not add properties to `root` in `shell.qml`. Use `GlobalStates`.
- **Raw JS Objects**: `JSON.parse()` results have NO QML signals. Never use them in `Connections` blocks.
- **Missing Defaults**: NEVER add a config key without updating `config/defaults/*.js`.
- **StyledRect bypass**: NEVER create raw `Rectangle` containers. Use `StyledRect` with a variant.

## DEFINITION OF DONE (every change)
A change is done only when all of these hold:
1. **`make check` is green.** It runs `parse-qml`, `lint-qml`, `fmt-check`, `lint-go`,
   `lint-sh`, `lint-py`, `audit` and `test` and prints a summary. `SKIP` (missing optional
   tool) is not a failure, but install the tool if you can (see "Quality tooling" below).
2. **No new lint findings.** qmllint and staticcheck have baselines of *pre-existing*
   upstream findings (`tools/lint/baselines/`). New code must not add any. Do not refresh a
   baseline (`make baseline`) to silence your own findings; it is only for tool false
   positives or for ratcheting after fixing old ones, and must be justified in the commit.
3. **New and already-clean files stay formatted** (`qmlformat` / `gofmt`; `make fmt`).
   Known-dirty upstream files are listed in `tools/lint/baselines/fmt-dirty.txt`; format
   one only if you own the change (it creates upstream merge noise).
4. **Config keys are registered everywhere** (`make audit` enforces it; after any change to
   `config/defaults`, `config/meta` or `modules/settings/schema` run `make schema`, the
   `schema-fresh` audit fails on a stale `assets/schema/`): the key exists in
   `config/defaults/<domain>.js` (its typed adapter `config/adapters/<Domain>Adapter.qml` is
   generated from it by `make schema`; whole-number or free-form keys need a type in
   `config/meta/AdapterTypes.js`); never edit the generated adapters; add it to the matching
   `GlobalStates` snapshot list (`_shellSections`, `_compositorProps`,
   `_simpleThemeProps`) if it is edited from a settings panel; every `Config.<domain>.<key>`
   used in QML must exist.
5. **Strings are translated**: every `I18n.t("key")` exists in `translations/en.json` and in
   every other language file (`es`, `ru`, ...).
6. **Small focused files.** New code goes in new, single-purpose components/services
   (rule of thumb: < 400 lines; 800 is the monolith limit reported by the audit). Do not
   grow files that are already over 800 lines (`make audit` shows growth vs `BASE`); extract
   a component instead. No dead code: delete files you make unused (`make audit` lists dead
   QML/JS files).
7. **Tested.** Logic in `.js` helpers gets a `tests/*.test.cjs`; QML behaviour gets a
   `tests/*.test.py` built on `tests/lib/qmlharness.py` (see `tests/README.md`).
8. **Data is argv, never code.** Never build `Qt.createQmlObject` source or a `sh -c`
   script from data (`+`, `${}`, `.arg()`, `.join()`): use a static `Component` and pass
   values as positional args (`["sh", "-c", 'cp -- "$1" "$2"', "name", src, dst]`). The
   `shell-injection` audit enforces it; exceptions need a reason in `tools/audit/config.json`.

### Quality tooling
| Command | What it does |
|---------|--------------|
| `make check` | Everything below + summary. `CHECKS="lint-qml audit"` runs a subset. |
| `make parse-qml` | Syntax check of every QML (qmllint `--bare`) and JS file (node). Never baselined. |
| `make lint-qml` | qmllint with `qs.*` resolved via a generated import mirror (`.cache/lint/qmltree`, see `tools/lint/qmltree.py`); `Config.<domain>` is typed there, so unknown config keys are reported. Fails on findings not in `tools/lint/baselines/qmllint.json`. |
| `make fmt-check` / `make fmt` | qmlformat (settings pinned in `.qmlformat.ini`) + gofmt; ratchet via `fmt-dirty.txt`. |
| `make lint-go` | `go vet` (strict) + `staticcheck` (baselined). |
| `make lint-sh` / `make lint-py` | shellcheck / ruff (`ruff.toml`), strict. |
| `make test` | `node --test tests/`, every `tests/*.test.py`, `go test ./...`. |
| `make audit` | Knip-like report (`tools/audit/`, `ARGS=--json`): config schema, translations, dead files, snapshot coverage, monoliths, generated catalog freshness, shell/QML injection. Allowlists with reasons in `tools/audit/config.json`. |
| `make schema` | Regenerate the settings catalog `assets/schema/*.schema.json` (JSON Schema 2020-12). |
| `make baseline` | Re-record lint/format baselines (rarely; justify it). |

Diff-based checks use `BASE` (default `origin/main`): `make check BASE=upstream/main`.
Optional pre-commit hook (parse + format on staged files + audit errors, ~1s):
`ln -sf ../../tools/hooks/pre-commit "$(git rev-parse --git-path hooks)/pre-commit"`.
User-local tool installs (no sudo): `uv tool install ruff`, `uv tool install shellcheck-py`,
`go install honnef.co/go/tools/cmd/staticcheck@latest`. qmllint/qmlformat come from Qt 6
(`/usr/lib/qt6/bin`; `/usr/bin/qmllint` on Arch is the Qt 5 one and is ignored).
Override with `QMLLINT`/`QMLFORMAT`; `QMLLINT_IMPORT_PATH` adds QML import dirs (CI uses
PySide6's bundled tools plus Quickshell's QML module from the pinned Arch package, see
`.github/workflows/check.yml`; keep its Qt/Quickshell pins equal to the baseline toolchain).

## COMMANDS
```bash
# Build the Go backend binary (outputs ./yozakura at repo root, gitignored)
make build
# Build + run the shell via the Go binary (the binary itself is the
# daemon: it supervises Quickshell, yozd and wl-paste children)
# (`make build` also builds ./yozd next to it)
make run
# Nix package build (backend)
make nix
# Quality gate (lint + format + audit + tests); must be green before done
make check

# Run shell directly (requires Quickshell + Hyprland)
qs -p shell.qml
# Or via the Go CLI binary (starts IPC, supervises children, execs qs):
./yozakura

# Install
make install    # sudo install of ./yozakura to /usr/local/bin

# Settings and presets from the command line (validated, hot-applied)
./yozakura config search <words> | describe <key> | get <key> | set <key> <value>
./yozakura preset list | apply <name> | save <name> | diff <a> <b>
./yozakura completion fish|bash|zsh
```

## NOTES
- Config keys are declared once, in `config/defaults/<domain>.js`; `config/adapters/` is generated
  (`make schema`, `tools/config/gen_adapters.cjs`). Use `pauseAutoSave` for bulk edits.
- Large files (>800 lines, `make audit` lists them): `ShellPanel`, `ThemePanel`, `PresetsTab`, `ModsPanel`, `MetricsTab`, `WeatherWidget`, `EmojiTab`. `ClipboardTab`, `NotesTab`, `TmuxTab`, `Wallpaper`/`WallpapersTab` and `Config.qml` are split into focused components; keep them that way.
- The `qs.` import prefix is a Quickshell VFS construct, not a physical directory.
- `screenshotToolMode` in `GlobalStates.qml` is **DEPRECATED**.
- **No QML disk cache for the shell.** Quickshell serves `import qs.*` files from its VFS
  (`qs:@/qs/...` URLs through a custom network access manager). Qt only reads/writes `.qmlc`
  for local `file:` URLs (`CompilationUnit::loadFromDisk/saveToDisk`: "File has to be a local
  file"), and Quickshell 0.3.1 keeps the `QML_DISK_CACHE_PATH` setup commented out for that
  reason (`src/launch/launch.cpp`). No env var (`QML_FORCE_DISK_CACHE` included) bypasses the
  URL check, so every start compiles every loaded QML/JS file; `~/.cache/quickshell/qmlcache`
  only holds the few files loaded by plain path. Bytecode compile of the whole tree
  (367 files, ~96k lines, `qmlcachegen --only-bytecode`) costs ~1.7 s single-threaded; the
  biggest are lazy dashboard tabs (ClipboardTab 85 ms, NotesTab 64 ms), compiled on first
  open. Keep startup-critical files small and push rarely used views behind `Loader`s. Do not
  switch to relative `import "../x"` imports to get caching: they create separate singleton
  instances from the `qs.*` ones.
- Gemini AI provider doesn't support the `system` role; handled in `services/ai/strategies/`.
- `yozd` is a core component: every compositor interaction goes through it (`backend/pkg/yozd`).

- Some projects to keep in mind for reference:
  - DankMaterialShell (DMS): https://github.com/AvengeMedia/DankMaterialShell
  - Noctalia: https://github.com/noctalia-dev/noctalia-shell
  - end-4 Dotfiles: https://github.com/end-4/dots-hyprland
  - Hyprland: https://github.com/hyprwm/hyprland
  - MangoWC: https://github.com/DreamMaoMao/mangowc
  - Niri: https://github.com/YaLTeR/niri
