# SERVICES KNOWLEDGE BASE

## OVERVIEW
Backend singletons bridging Wayland protocols, CLI tools (nmcli, upower, wpctl, etc.), and AI providers to the QML UI layer. 30+ services following a "Reactive Singleton" pattern — internal state derived from async system calls, exposed as QML properties.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Audio/Volume** | `Audio.qml` | PipeWire/PulseAudio via `wpctl`. Sink/source management |
| **Network/WiFi** | `NetworkService.qml` | `nmcli` wrapper. WiFi scanning, connection, status |
| **Battery/Power** | `Battery.qml` | UPower integration. Percentage, charging state, time remaining |
| **Bluetooth** | `BluetoothService.qml` | Device listing, connect/disconnect |
| **Brightness** | `Brightness.qml` + `BrightnessWrite.js` | Per-monitor brightness via `brightnessctl` / `ddcutil`. Writes are single-flight, latest-wins (a DDC write is 150-350 ms and ddcutil serialises calls); never spawn one process per tick |
| **AI Assistant** | `Ai.qml` + `ai/strategies/` | Multi-provider (OpenAI, Gemini, Mistral). Strategy pattern |
| **Voice input** | `VoiceService.qml` + `voice/VoiceModel.js` | Client of the backend `voice` service (local whisper.cpp). Sets `panelOpen`/`panelScreen` while a session is shown, which opens the notch registry panel `voice` (`modules/widgets/defaultview/panels/VoicePanel.qml`); routes transcripts to `Ai.handleVoice(text, "sidebar"|"notch")` (fallback: open sidebar + `sendMessage`) or types them via `voice.type`. Dismissing the panel (`dismiss()`) cancels an active session |
| **Clipboard** | `ClipboardService.qml` | Persistent clipboard via `clipboard.db` + helper scripts |
| **Media** | `MprisController.qml` | MPRIS D-Bus player control |
| **Notifications** | `Notifications.qml` | D-Bus notification server with persistence |
| **System Monitor** | `SystemResources.qml` | CPU, RAM, GPU, temps via Python script |
| **Compositor** | `YozdService.qml` + `YozdClients.js` | Compositor abstraction. State arrives via `BackendService` subscription to the Go-owned `compositor` service (coalesced to one push per ~16 ms in Go); clients are diffed by address so unchanged ones keep their object identity; `dispatch()` is an IPC call to the backend that runs `yozd` one-shots |
| **Compositor appearance** | `CompositorConfig.qml`, `CompositorAppearance.js`, `CompositorTomlWriter.qml` | One hl.config() table applied live (eval) and persisted (backend renders hyprland.{lua,conf}); smart gaps = a `w[tv1]` workspace rule |
| **Motion profile** | `CompositorMotion.qml` + `config/motion/` | Resolves `compositor.motionProfile` + overrides into curves/animations; applied live, persisted via the TOML payload (`motion`) |
| **Music-reactive border** | `BorderPulse.qml` + `BorderPulse.js` | Owned by `CompositorConfig`. Idle unless enabled + a player is playing (and off in GameMode or while `BatterySaver.active`); cava (shared `CavaService` consumer) → quantized level → one `eval` on Hyprland's request socket per level change (≤30 Hz) |
| **Visibility** | `Visibilities.qml` | Per-screen UI visibility/layering orchestration |
| **State** | `StateService.qml` | JSON persistence for session state (tab positions, etc.) |
| **Focus** | `FocusGrabManager.qml` | Input focus coordination across overlays |
| **Desktop** | `DesktopService.qml` | Desktop icon grid positioning and management |
| **App Search** | `AppSearch.qml` | Application indexing for launcher |
| **Weather** | `WeatherService.qml` | Forecast, sunrise/sunset, day/night detection |
| **Keybinds** | `GlobalShortcuts.qml` | Compositor-level keybind management |
| **Live activities** | `activities/` | `ActivityService` aggregates providers listed in `ActivityProviders.qml`. New source = one `pragma Singleton` + `ActivityProvider { source; activities; activate() }` file + one registry entry (+ a `notch.liveActivities.sources` default to make it toggleable). Pure logic in `ActivityModel.js`, `PrivacyDetect.js`, `NotificationProgress.js` |

## CONVENTIONS
- **Process role**: Settings and the setup wizard may run as separate Quickshell
  processes (`performance.separateWindows`; `SeparateWindows.qml` + `PreviewSink.qml`
  are the main shell's side). A service that claims something session-wide or
  repeats the main shell's work (a D-Bus name, an IPC stream whose events it
  acts on, a FIFO, idle hooks, a compositor or app-theme write, timers that
  notify, history / usage files, scheduled network checks, the heartbeat) does
  it only when `ProcessRole.primary` (modules/globals), decided at construction.
  Gated today: Notifications (server, history, `notify` stream; notifyInternal
  goes to `notify.send`), GlobalShortcuts (FIFO, running commands; `ui` stream
  only for the wizard's tour), IdleService / IdleMonitor, CompositorTomlWriter,
  CompositorMotion, TimersService, UpdateService (scheduled), UsageTracker
  (writes), WallpaperCommandService, PresetCommandService, FocusMode, Battery
  (alert), Ai (automations), AppHooksService (auto-connect), SpecialsService,
  OnboardingService (auto-show), BackendService (heartbeat), Colors (app-theme
  generators). Judged safe in a window: read-only subscriptions (YozdService,
  DisplaysService, ExtrasService, NetworkService, PresetStatusService, ...),
  KeyboardService (applies the same layout as the main shell, keeps the
  page's error), IpcHandlers (`qs ipc` targets the main shell's pid). The
  polkit agent (another branch) belongs to the main shell the same way.
- **Singleton pattern**: `pragma Singleton` + `Singleton { id: root }` root component.
- **System access**: Prefer `Quickshell.Io.Process` with `SplitParser` for line-by-line stdout handling.
- **Naming**: Properties in camelCase (`wifiEnabled`, `isCharging`). Methods: `update()` for polling, `toggleX()` for booleans. Signals: past-tense or action-based (`initDone`, `discard`).
- **Persistence**: `FileView` for direct JSON manipulation. Reference `Config` for global settings; keep service-specific state local.
- **Async safety**: `Qt.callLater()` when modifying lists/models inside process handlers.
- **Self-init**: Services handle own lifecycle via `Component.onCompleted: update()`.
- **Error handling**: Always provide safe fallback values (`available: device !== null`).

## ANTI-PATTERNS
- Polling without a timer guard (use `Timer` with configurable intervals).
- Modifying list models synchronously inside `Process.onStdout` handlers.
- Creating new services without registering them in `shell.qml` init sequence.
