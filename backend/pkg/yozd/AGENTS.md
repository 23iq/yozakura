# yozd — compositor IPC daemon

`yozd` is the compositor abstraction the `yozakura` backend supervises
(`pkg/svc/compositor`): one JSON-RPC API over a unix socket for Hyprland,
niri and MangoWC, plus idle monitors/inhibitors, brightness, dark mode and
compositor config generation from `~/.local/share/yozakura/yozd.toml`.
Derived from an upstream project (AGPL-3.0, see `NOTICE`); it is our code
now — extend it here.

## Identity
The name lives in `pkg/brand` only: `brand.Daemon` (binary), and derived
`brand.DaemonSocketPath()` (`$YOZD_SOCKET`, else
`$XDG_RUNTIME_DIR/yozd.sock`, else `/tmp/yozd-<uid>.sock`),
`brand.DaemonConfigFile()`, `brand.DaemonEnv()`, `brand.DaemonLog()`.
Never write the literal; QML uses `Brand.daemon` / `Brand.daemonArgs()`,
Go callers run `paths.DaemonBinary()` (next to the running executable, then
PATH).

## Layout
```
cmd/yozd/            CLI: daemon, subscribe, window|workspace|monitor|layout|
                     config|system|darkmode|brightness|overview <action>
                     (client side builds "Group.Method" requests)
pkg/yozd/
├── client/          System.Subscribe stream client, shared by `yozd subscribe`
│                    and the backend's in-process subscriber (pkg/svc/compositor)
├── ipc/             Compositor interface (interface.go), shared types,
│   │                config payloads (config.go), cache, colors
│   ├── hyprland/    socket2 events + dispatch, conf/Lua generators
│   ├── niri/        JSON request/reply, KDL generator
│   ├── mango/       dwl-ipc client, conf generator
│   ├── mock/        test compositor (call tracking, error injection)
│   └── wayland/     generated protocol bindings (see wayland/AGENTS.md)
├── config/          TOML loader (imports), types -> ipc.Config, apply, watcher
├── server/          socket server + method dispatch (server.go), idle
│                    monitors/inhibitors (idle.go), brightness, darkmode,
│                    config state and generated-file paths
└── keymon/          physical input monitor (idle resume, modifier-only binds)
```

## Rules
- Wire protocol and CLI output are consumed by the shell (`YozdService`,
  `IdleMonitor`, `CompositorConfig`, `Screenshot`, `GlobalStates`) and the
  backend (`pkg/svc/compositor`, `caffeine`, `axmon`, MCP tools). Change
  them together with every caller.
- A new compositor implements `ipc.Compositor` in its own package and is
  added to the detection order in `cmd/yozd/main.go`.
- New methods go in `server/binds.go` `dispatchExtra` (reached from the
  `default:` of the switch in `server.go`, which must not grow), e.g.
  `Config.ListBinds` (`yozd config list-binds`; compositors implement the
  optional `ipc.BindLister`) and `Config.SkippedBinds`
  (`yozd config skipped-binds`; generators that drop binds implement
  `ipc.BindSkipper`; niri drops release, duplicate-combo and unmappable binds).
- Generated config apply (`server/config_handler.go`): a byte-identical
  regeneration neither writes nor reloads. On Hyprland the sections are
  diffed (`server/reload_plan.go`): appearance/keyboard-only changes go out
  live (`keyword` batch, or `eval` on Lua Hyprland) without a reload; binds,
  rules, monitors, env, startup, animations or a removed key reload. A new
  section that a runtime command can carry belongs in `liveSections`. The
  live-path write runs under `Hyprland.SuppressAutoreload` (runtime
  `misc:disable_autoreload`, restored after a quiet period, untouched when
  the user turned it off), else Hyprland's own autoreload would reload on
  the write. Every reply of the `[[BATCH]]` is checked
  (`ipc/hyprland/batch.go`: a `keyword` must answer `ok`); a rejected one
  falls back to a reload, and a failed reload drops the applied record so
  the next apply reloads too. A live `keyword` beats a value the user's own
  config sets after sourcing the generated file until the next reload, so
  keys the user sets again after it (`server/hypr_overrides.go`, following
  `source =` from `~/.config/hypr/hyprland.conf`, our generated entry files
  excluded; hyprlang only, a Lua config is not inspected) reload instead.
  Generators must be deterministic: range over
  `ipc.SortedKeybindNames`, never over a map, or no regeneration is ever
  byte-identical.
- `Monitor.Width/Height` differ per compositor (Hyprland: raw mode pixels,
  unrotated and unscaled, the shell rotates/scales them itself; niri and
  MangoWC: layout size). Every backend also sends `metadata.logical_width`
  / `logical_height` (layout coordinates); hit-testing uses those
  (`axmon.Containing`). Hyprland adds `metadata.screencopy_logical`
  (>= 0.57 sends screencopy frames already rotated; `pkg/capture`).
- Tests: `go test ./pkg/yozd/... ./cmd/yozd` (mock compositor, no live
  session needed).
