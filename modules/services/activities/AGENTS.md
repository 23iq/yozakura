# LIVE ACTIVITIES (modules/services/activities)

## OVERVIEW
Things happening right now (recording, mic/camera/screen sharing, timers,
downloads/copies/updates) collected from **providers** and shown by the
notch (`bar.activities.presentation: "notch"`, default,
`modules/widgets/defaultview/activities/`) or as islands next to it
(`"islands"`, `modules/bar/activities/`). `"off"` stops every provider.

## DATA FLOW
```
provider singletons ──activities──┐
 (one file per source)            ├─> ActivityService ──> notch / islands UI
TransferProvider files ─transfers─┘     activities (sorted, deduped; transfers
   ^                                    become one "downloads" activity)
   │ itemsBySource                      tasks / privacy / transfers
TransfersBackend ── BackendService ──> backend/pkg/svc/transfers (Go)
   transfers.configure {sources, options}   one Go file per source
   transfers.state {items}  (≤ 2/s)         sources run only while enabled
   transfers.action {id, action}
```

## ADDING A SOURCE
- QML-only activity: `pragma Singleton` + `ActivityProvider { source; activities; activate() }`.
- Transfer computed in QML: set `transfers` (TransferModel.js shape) instead.
- Backend transfer source: Go file in `backend/pkg/svc/transfers/` calling
  `register("<name>", ...)` in `init()`, plus a 5-line QML file
  `TransferProvider { source: "<name>" }`.
- Then: one entry in `ActivityProviders.qml`, a default in
  `config/defaults/bar.js` + `Config.qml` (`activities.sources.<name>`),
  `ActivityModel.js DEFAULT_CONFIG`, a settings toggle in
  `BarActivitiesSettings.qml` and en/es/ru strings.

## PURE LOGIC (unit tested, `tests/activities.test.cjs`, `tests/transfers.test.cjs`)
- `ActivityModel.js`: config normalisation, priority sort, de-duplication.
- `TransferModel.js`: transfer shape, cross-source de-duplication (same file
  name, partial suffixes stripped; notifications matched by the file name
  in their text; richer source wins), summary (bytes-weighted progress,
  summed rate, ETA), units/ETA formatting, `toActivities()`.
- `PrivacyDetect.js`, `NotificationProgress.js`.

## SOURCES
| Source (`activities.sources`) | Where | What is detected | Limitations |
|---|---|---|---|
| `recording` | `RecordingActivity.qml` | Yozakura's screen recorder | other recorders appear under `privacy` (screen capture) |
| `privacy` | `PrivacyActivity.qml` | PipeWire link groups (bound, so `state` is valid) into input streams: mic, camera (v4l2/libcamera nodes), screen cast; `/dev/video*` readers via `scripts/camera_users.sh` (inotify) | apps that capture without PipeWire/v4l2 are invisible |
| `timers` | `TimerActivity.qml` | the backend timers (`TimersService`, svc/timers): running timers/Pomodoro (ring or text, `system.timers.*`), ringing ones as a pulsing alarm, the running stopwatch, reminders due within `system.timers.reminderLead` min | paused timers only in the panel |
| `notificationProgress` | `NotificationProgressActivity.qml` | notifications with the `value` hint; synchronous re-sends update one item (newest wins) | percent only, no sizes/speed |
| `jobView` | `backend/.../jobview.go` | KDE job tracking (Dolphin/KIO, Ark, KGet, Plasma browser integration): claims `org.kde.JobViewServer` + `org.kde.kuiserver` (only when free) and serves `JobViewServer.requestView` → `JobViewV2` and `JobViewServerV2.requestView` → `JobViewV3`; cancel/suspend/resume go back as `*Requested` signals | inactive under Plasma (it owns the name); keeps the name if Plasma starts later |
| `browserDownloads` | `browser.go` | `*.part` (Firefox family), `*.crdownload` (Chromium family), `*.opdownload` (Opera) in `XDG_DOWNLOAD_DIR`; inotify, 1 s size sampling only while partial files exist; owner via `/proc/*/fd`; rename → done, vanish → cancelled, 10 s without growth → stalled | no totals on disk → indeterminate ring; top level of the folder only |
| `terminal` | `terminal.go` | curl, wget/wget2, aria2c, yt-dlp, gallery-dl, axel, lftp, megadl, spotdl: largest regular file opened for writing (side files ignored, `.part` stripped); speed from growth | totals unknown; own processes only |
| `fileOps` | `fileops.go` | like `progress`: cp, mv, dd, rsync, scp, pv, tar, compressors, 7z/zip/unrar, ffmpeg; `fdinfo` `pos` of the largest read-only input (≥ 1 MiB) vs its size | archives show one large file at a time; same-filesystem `mv` is instant; own processes only |
| `packages` | `packages.go` | pacman-family processes + `db.lck`: growing `*.part` in pacman's CacheDir (size/speed) else indeterminate "Updating system"; `flatpak install/update` processes | package totals unknown; flatpak progress not readable |
| `steam` | `steam.go`, `steam_vdf.go` | every library from `libraryfolders.vdf` (native, `~/.steam`, flatpak roots); `appmanifest_*.acf` StateFlags + BytesDownloaded/ToDownload then BytesStaged/ToStage; `content_log.txt` state lines and "Current download rate: N Mbps"; inotify + 2 s polling while Steam runs; click opens `steam://nav/downloads`; shader pre-caching as a secondary item | rate updates only as often as Steam logs it (~30 s); postponed/queued updates only show while Steam is active, so idle partial updates never pin an island |
| `torrents` | `torrents.go`, `torrent_*.go` | qBittorrent WebUI v2, Transmission RPC (session-id handshake), Deluge web JSON-RPC; polled every 2 s only while the client process runs; incomplete torrents only | read-only; qBittorrent needs localhost auth bypass or `downloads.secrets.qbittorrent` ("user:pass"); deluge-web must already be connected to a daemon |
| `aria2` | `aria2.go` | aria2c with `enable-rpc` (cmdline or aria2.conf, port/secret from there): tellActive/Waiting/Stopped; cancel/pause/resume actions | aria2c without RPC is covered by `terminal` |
| `syncthing` | `syncthing.go` | API key/address/folders from `config.xml`; one item per folder that is syncing with needed bytes; rate from received-bytes deltas | GUI on a unix socket unsupported; folders waiting for an offline peer are not shown |
| `launchers` | `launchers.go` | Heroic helpers (legendary/gogdl/nile) + newest Heroic log progress lines; Lutris installer processes (indeterminate) | best effort, fixture-tested only; Lutris internal downloads are invisible |

Endpoints/secrets live in `bar.activities.downloads.endpoints` / `.secrets` (bar.json).
