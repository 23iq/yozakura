# CONFIG KNOWLEDGE BASE

## OVERVIEW
Reactive, file-backed configuration system built on `Quickshell.Io`. Source of truth for all shell modules. Stores JSON in `~/.config/yozakura/config/`. Gracefully handles missing/malformed files by falling back to hardcoded defaults.

## STRUCTURE
- **Config.qml**: Core singleton. One `ConfigFile` per domain (bar, theme, ai, dock, ...) exposed as typed `Config.<domain>` (`property BarAdapter bar`), `<domain>Ready` flags, `initialLoadComplete`, derived values (`animDuration`, `compositor*`), color helpers, `save<Domain>()`.
- **ConfigFile.qml**: one domain's `FileView`: path `<configDir>/<name>.json`, first load validates against the defaults (or copies the preset / writes defaults when missing), later reloads fill missing top-level keys, adapter edits write back unless `pauseAutoSave`.
- **adapters/*.qml** (GENERATED, do not edit): the typed `JsonAdapter` of each domain, built by `tools/config/gen_adapters.cjs` (`make schema`) from `defaults/<domain>.js` + `meta/AdapterTypes.js`; `KeybindsAdapter.qml` from `CoreBinds.js` + `CustomBindDefaults.js`. The `schema-fresh` audit fails when stale; `tests/config-adapters.test.py` checks every key/type/default.
- **KeybindsFile.qml**: binds.json (`Config.keybindsLoader`): creation, repair/migration of old layouts, custom-bind normalization.
- **defaults/*.js**: JavaScript modules exporting a `data` object — the blueprint for initial file generation and validation baseline. Files: `bar.js`, `theme.js`, `ai.js`, `compositor.js`, `dock.js`, `notch.js`, `desktop.js`, `overview.js`, `notifications.js`, `tools.js`, `lockscreen.js`, `system.js`, `weather.js`.
- **ConfigValidator.js**: Recursive `validate()` function for deep-merging user settings with defaults. Handles type coercion and constraint enforcement (e.g., `gradientType` must be `"linear"`, `"radial"`, or `"halftone"`).
- **pam/**: PAM configuration for lockscreen authentication.
- **meta/**: catalog metadata (description, enum, range, item types) of keys the settings schema does not describe; `Enums.js` holds the allowed-value lists shared with `ConfigValidator.js`. `make schema` merges defaults + meta + settings schema into `assets/schema/` (the `schema-fresh` audit checks it).

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Add config key** | `defaults/<domain>.js` + `make schema` | Adapter is generated; `int`/`var`/empty-list keys need a type in `meta/AdapterTypes.js` (numbers default to `real`) |
| **Validation logic** | `ConfigValidator.js` | Recursive `validate()` with type constraints |
| **Bootstrapping** | `Config.qml` (`Process`), `ConfigFile.qml` | Copies preset files, falls back to defaults for missing JSON |
| **File sync** | `ConfigFile.qml` + `adapters/` | Each domain has isolated persistence |
| **Bulk updates** | `Config.qml` (`pauseAutoSave`) | Prevents multiple disk writes during batch changes |
| **Load gating** | `Config.qml` (`initialLoadComplete`) | Guards components needing fully-initialized config |

## CONVENTIONS
- **Atomic defaults**: ALWAYS update `defaults/*.js` when adding new config keys.
- **Bind to Config**: UI elements bind to `Config.<module>.<property>`. Never use local state for persistent settings.
- **Auto-save**: `JsonObject` changes auto-persist via `FileView`. Use `root.pauseAutoSave` for bulk updates.
- **Reactive defaults**: Config access may occur during load/reload. Gate with `initialLoadComplete` if needed.
- **JSON formatting**: 4-space indent for human readability.

## ANTI-PATTERNS
- Adding a config key without a corresponding default in `defaults/*.js`.
- Modifying `Config` properties directly outside the `JsonAdapter` binding system.
- Reading config values before `initialLoadComplete` without a null guard.
