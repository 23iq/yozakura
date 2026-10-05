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
- Tests: `go test ./pkg/yozd/... ./cmd/yozd` (mock compositor, no live
  session needed).
