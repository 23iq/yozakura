# Yozakura guide for AI agents (and power users)

This is the map for changing Yozakura without guessing: how the project is
organised, how to change the look, layout, presets and keybinds through the
CLI or MCP, 40+ recipes, where the code of each feature lives, and how to add
a setting, bar module, notch panel, preset or clock style.

Everything below was run against a throwaway `$HOME`. Commands show the
binary as `yozakura` (the repo build is `./yozakura` after `make build`).

## 1. How the project is organised

| Layer | Where | What |
|---|---|---|
| Shell UI | `shell.qml`, `modules/` | Quickshell/QML: bar, notch, dock, launcher, dashboard, settings window, lock screen, desktop, notifications |
| Config | `config/defaults/<domain>.js`, `config/Config.qml` (+ `ConfigFile.qml`, generated `config/adapters/`), `config/ConfigValidator.js` | One JSON file per domain in `~/.config/yozakura/config/<domain>.json`; defaults are the blueprint, the validator drops unknown keys and resets invalid values |
| Settings catalog | `assets/schema/*.schema.json` (generated) | JSON Schema 2020-12 of every key: type, default, title, description, enum, range, settings page, `visibleWhen`. Built from `config/defaults`, `config/meta/*.js` and `modules/settings/schema/*.js` by `make schema` |
| Settings UI | `modules/settings/` | Schema-driven window (`schema/<category>.js` declares entries) |
| Backend | `backend/` (Go) | The `yozakura` binary: daemon supervising Quickshell, IPC (JSON-RPC over a unix socket), CLI, `yozakura mcp` server |
| Compositor daemon | `backend/cmd/yozd`, `backend/pkg/yozd/` (Go) | The `yozd` binary the backend supervises: one JSON API over Hyprland/niri/MangoWC (`yozd window list`, `yozd workspace list`, `yozd monitor list`, `yozd subscribe`), idle monitors and inhibitors, brightness, compositor config generation from `~/.local/share/yozakura/yozd.toml` |
| Presets | `assets/presets/<Name>/` (built in), `~/.config/yozakura/presets/<Name>/` (user) | A directory of domain files plus `info.json` |
| Keybinds | `~/.config/yozakura/binds.json`, `config/KeybindActions.js` | Core binds (`yozakura.*` actions) and custom compositor binds |
| Wallpapers | `~/.cache/yozakura/wallpapers.json` | Current wallpaper per monitor, matugen scheme, colour preset |
| Identity | `backend/pkg/brand`, `modules/globals/Brand.qml` + `BrandActions.js`, `scripts/lib/brand.*` | Never hard-code the app id |

Config domains: `ai bar compositor desktop dock general lockscreen notch
overview performance prefix specials system theme voice weather workspaces`
(`yozakura config list` prints them with a description each).

Keys are always `<domain>.<dotted.path>`: `bar.position`,
`bar.layout.style`, `theme.srBg.opacity`. Array items are `key.N` or
`key[N]`.

**Hot apply.** The running shell watches every config file
(`FileView { watchChanges: true }`), so a write through the CLI or MCP is
live within a frame. Writes are atomic (temp file + rename, like the shell's
own `atomicWrites`) and keep key order. You never need to restart the shell
for a config change.

## 2. The CLI

```bash
yozakura config list                      # domains with descriptions and key counts
yozakura config list bar                  # keys under a domain or key, current values (* = not default)
yozakura config list bar --json           # same, machine readable (key, type, value, default, modified)
yozakura config search bar height         # find keys by words (synonyms: "transparency" -> opacity, ...)
yozakura config describe theme.roundness  # title, description, type, allowed values, range, default,
                                          # current, settings page, visibleWhen, file
yozakura config describe bar.position --json
yozakura config get bar.position          # strings print bare: top
yozakura config get bar.layout            # objects/arrays print as JSON
yozakura config set bar.position bottom   # validated; prints: bar.position: "top" -> "bottom"
yozakura config toggle bar.compact        # flip a boolean
yozakura config reset theme.roundness     # back to the default (objects: every leaf below)
yozakura config reset compositor --yes    # a whole domain needs --yes
yozakura config schema bar                # JSON Schema of a domain (no argument: the combined one)
yozakura config path bar                  # the live file of a domain
```

`config set` value syntax: booleans `true/false/on/off/yes/no/1/0`, numbers
(`-1` is a value, not a flag), strings verbatim (`"quoted"` JSON strings are
unquoted), arrays as JSON (`'["a","b"]'`) or a comma list (`a,b`; an empty
string clears the list), objects as JSON (merged member by member, e.g.
`'{"enabled":false}'`). Flags:

| Flag | Effect |
|---|---|
| `--json` | parse the value as JSON whatever the type |
| `--add <item>` / `--remove <item>` | add/remove one array item |
| `--dry-run` | validate and print the change without writing |
| `--force` | skip enum/range/pattern checks (the type is still checked) |

Some numeric keys also accept a sentinel outside their range, shown as `special:` by `describe` (e.g. `-1` = inherit/auto for `theme.glass.*`).

Validation errors say exactly what is allowed:

```
$ yozakura config set bar.position up
Error: bar.position must be one of top, bottom, left, right, got "up"
$ yozakura config set theme.roundness 30
Error: theme.roundness must be in 0..24, got 30
$ yozakura config set bar.positon top
Error: unknown key bar.positon; did you mean bar.position? (see `config list bar`)
$ yozakura config set bar.layout.left launcher,launcher
Error: bar.layout.left: duplicate item "launcher"
```

Presets:

```bash
yozakura preset list [--json]             # official first, * = active (also: `yozakura preset`)
yozakura preset apply "Neon Tokyo"        # copies the preset's files over the live config (also: `yozakura preset "Neon Tokyo"`)
yozakura preset save Backup [--force]     # live config -> user preset (private domains + machine-local keys never included)
yozakura preset save "Only colors" --domains theme
yozakura preset diff Backup current       # key-by-key differences ("current" = live config, files allowed)
yozakura preset export current look.json  # single-file bundle {"format":"yozakura-preset","version":1,...}
yozakura preset import look.json --name Shared [--force]
yozakura preset active                    # last applied preset
yozakura preset show "Neon Tokyo" [--against Sumi-e] [--json]
                                          # what it changes per aspect (vs defaults), settings page per key,
                                          # presets sharing each aspect
yozakura preset aspects                   # layout | colors | windows | desktop | lockscreen (files/keys each covers)
yozakura preset mix Blend --layout Kaze --colors "Neon Tokyo" --windows CRT
yozakura preset duplicate Sumi-e "My ink" # built-ins are read-only: duplicate to customise
yozakura preset rename "My ink" Ink | delete Ink (-> trash, `restore <id>` within 7 days) | trash
yozakura preset update Ink [--domains theme]   # overwrite a user preset with the live config
yozakura preset set-info Ink --description "..."
yozakura preset try CRT                 # trial: backs up the live look; `try --keep` / `try --revert`
yozakura preset edit Ink                  # applies it so settings edit it; `edit --save [--keep]` / `edit --cancel`
```

Special workspaces (Hyprland scratchpads; global like the keybinds, never in
presets; stored in `specials.json`):

```bash
yozakura special list [--json]            # name, special:<name>, binds, apps
yozakura special open Telegram            # open/close (the shell launches its apps first)
yozakura special add Chat --template chat --toggle SUPER+S --send SUPER+ALT+S
yozakura special set Chat --name Talk --accent tertiary --preload on   # rename keeps its windows
yozakura special app add Talk org.telegram.desktop --if-running move --rule
yozakura special app add Talk --match vesktop --command vesktop
yozakura special app remove Talk vesktop | special remove Talk
yozakura special import-binds [--dry-run] # move hand-written special binds out of ~/.config/hypr/custom
```

Exclusive mode (Hyprland only: make Yozakura the only shell, with a backup):

```bash
yozakura install hyprland --exclusive [-y]   # lists backup path, units, imported monitors/keyboard, asks y/N
yozakura install --restore [--from DIR] [-y] # newest backup unless --from; the backup is kept
```

IPC `exclusive.status | plan | enable | restore` (backend `pkg/exclusive`,
service `pkg/svc/exclusive`, `ExclusiveService.qml`, Settings > System card
`modules/settings/system/ExclusiveCard.qml`). Backups live in
`~/.local/share/yozakura/backups/<time>/`; while active `displays.conflicts`
reports nothing (the old files are no longer loaded).

Monitors and keyboard layouts (talk to the running backend; `--json` on lists):

```bash
yozakura display list
yozakura display set DP-1 --mode 2560x1440@165 --scale 1   # also --rotate 90, --vrr on, --pos 1920x0, --disable
yozakura display set DP-1 --mode preferred --yes           # --yes keeps without asking
yozakura keyboard list | add ru | add us:intl | remove ru
yozakura keyboard switch-bind alt_shift|super_space|caps|ctrl_shift|none
yozakura keyboard next                                     # switch layout now
```

`display set` applies live, prints `Keep? (y/N, auto-revert in 15 s)` on a
terminal and reverts unless you answer y (a kept change is saved to
`displays.monitors`). Without a terminal and without `--yes` it reverts after
the timeout and exits 3. `keyboard` writes `keyboard.layouts` /
`keyboard.switchBind` through the same validated layer as `config set`.
Until the user changes the keyboard in Yozakura (`keyboard.managed` false)
nothing keyboard-related is rendered or applied and the compositor's own
settings stay in effect (`keyboard list` shows them, read via the backend's
`keyboard.current`); the first `keyboard add/remove/switch-bind` (or MCP
`keyboard_set`, `config set keyboard.<key>` / MCP `config_set`, or an edit in
Settings > Keyboard / onboarding) copies them into the domain and sets
`managed` first, in one write. Hyprland reports them live (`getoption`); on
niri / MangoWC they are read from the user's config file. When they cannot be
read at all, the takeover replaces them and needs `--replace` (MCP
`"replace": true`, UI: the "Let Yozakura manage the keyboard" button). An
empty `displays.monitors` likewise renders no monitor lines.

Keybind advisor (`backend/pkg/binds`; edits `binds.json` only, never the
compositor config; `--json` everywhere):

```bash
yozakura binds search переключить раскладку  # actions, apps, launcher commands, workarounds (any language)
yozakura binds list --source compositor      # shell-core | shell-user | shell-special | compositor
yozakura binds check SUPER+SHIFT+S           # free? who uses it, reserved combos
yozakura binds suggest window.toggle-float   # free ergonomic combos (SUPER+letter of the label first)
yozakura binds set SUPER+B apps.launch app=firefox   # --replace, --additional, --name
yozakura binds rm SUPER+B                    # core binds are switched off, custom ones removed
yozakura binds undo <token>                  # every set/rm prints its undo command
```

Shell UI commands (need the running shell): `yozakura run <command>` with
`launcher clipboard emoji tmux notes terminal dashboard wallpapers assistant overview
powermenu tools config screenshot screenrecord lens lockscreen
media-play-pause media-next media-prev brightness-up brightness-down
dnd-on dnd-off dnd-toggle ai-quickask ai-selection ai-region ai-code
(Code space; `ai-agent` is an alias) ai-chat (Assistant space; `ai-shell` is an alias)`
(see `modules/services/GlobalShortcuts.qml`);
`yozakura toggle bar` pins/unpins the bar; `yozakura wallpaper <file>
[-scheme scheme-tonal-spot] [-oled] [-monitor DP-1]`.

Quick commands (the launcher's `>` commands, one registry
`assets/commands/commands.json`): `yozakura cmd list [--json]` lists them,
`yozakura cmd dnd`, `yozakura cmd glass 0.6`, `yozakura cmd preset "Neon
Tokyo"`, `yozakura cmd wallpaper random`, `yozakura cmd theme light` run
one. UI commands need the running shell; config and CLI ones do not.
`yozakura onboarding` reopens the welcome / setup wizard.
`yozakura onboarding --dry-run [--keep]` runs it in a separate Quickshell
(`onboarding-dryrun.qml`) where every button is safe: the XDG
config/cache/state dirs are a temp dir of plain copies (no symlink back),
and `BackendService` fails closed: only the reads listed in
`modules/services/DryRunMethods.js` reach the daemon, everything else is
mocked (`DryRunBackend.js`: fake 15 s display session, fake installs,
`YOZAKURA_DRYRUN_FAIL=id1,id2` fails those). The journal of what it would
have done is printed on exit (`modules/globals/DryRun.qml`).

Timers, stopwatch and reminders (daemon `timers` service, persisted in
`~/.local/share/yozakura/timers.json`, counted by wall clock so they survive
restarts; a finished timer rings with a notification "+5 min" / "Stop"):

```bash
yozakura timer 10m tea                    # times: 10m, 1h30, 1h30m, 90s, 25 (= minutes), 1:30:00, 18:00, 7:30pm
yozakura timer list [--json]              # timers, stopwatch and reminders
yozakura timer pause|resume|reset|cancel [id|name]   # id optional with one timer
yozakura timer add t3 5m                  # "-1m" removes time; on a ringing timer it snoozes
yozakura timer stop                       # stop every ringing timer
yozakura timer pomodoro [50m] [10m]       # work/break cycles (defaults: system.pomodoro.*)
yozakura stopwatch start|pause|resume|toggle|lap|reset|status
yozakura remind 18:00 call mom            # or: remind in 20m stretch; remind list; remind cancel r4
```

Routines (daemon `routines` service, `~/.config/yozakura/routines.json`):
deterministic step lists — bind actions, built-in MCP tools, delays — run by
a keybind (action `utilities.routine` `{"routine": "<id>"}`, one "Not set"
slot per routine in Keybinds → Utilities), the launcher (by name), an AI
automation (output "routine") or the AI. Edited in Settings → Routines.

```bash
yozakura routine list [--json]            # id, name, step count
yozakura routine show morning             # steps with their args
yozakura routine run morning              # per-step report (exit 1 when a step failed)
yozakura routine save routine.json        # or "-" for stdin: {"name","icon","steps":[{"kind":"tool","tool":"dnd_set","args":{"enabled":true}},{"kind":"delay","ms":2000},{"kind":"action","action":"media.next"}]}
yozakura routine delete morning
```

AI coding tasks (daemon `tasks` service, state in
`~/.local/share/yozakura/tasks/`; each run works in its own git worktree under
`~/.local/share/yozakura/worktrees/<project>/<id>` on branch `yoz/<id>`; when the
agent finishes, the project check runs and failures go back to it, then the
task waits for review; accept squashes it into the current branch):

```bash
yozakura task new "Add a --json flag to list" --agent claude,codex [--plan] [--in-place] [--template tests]
yozakura task list [--json]               # id, status, agents, title
yozakura task show k1abc                  # runs, checks, changed files, plan
yozakura task run k1abc                   # approve the plan (plan mode)
yozakura task followup k1abc "also update the docs" [--run 1]
yozakura task accept k1abc [--run 1] [-m "feat: ..."]   # one commit on the current branch
yozakura task discard k1abc               # remove worktrees and branches
yozakura task project . --check "make check" --max-attempts 2   # or --auto (detect)
yozakura task templates                   # /review /tests /fix-check /explain /refactor + your own
```

Templates: `assets/ai/task-templates/*.md` (bundled),
`~/.config/yozakura/task-templates/*.md` (global), `<project>/.yozakura/templates/*.md`
(project); front matter `name`, `description`, `mode`; placeholders
`{{input}} {{selection}} {{file}} {{clipboard}} {{diff}} {{staged}} {{branch}} {{project}} {{check}}`.

Completion: `yozakura completion bash|zsh|fish` (keys, values and preset
names are completed live from the catalog):

```bash
yozakura completion fish > ~/.config/fish/completions/yozakura.fish
yozakura completion bash > ~/.local/share/bash-completion/completions/yozakura
yozakura completion zsh  > "${fpath[1]}/_yozakura"
```

## 3. MCP (for agents)

`yozakura mcp` is a stdio MCP server (newline-delimited JSON-RPC). Register
it in your agent, e.g. Claude Code: `claude mcp add yozakura -- yozakura mcp`.
`yozakura mcp --list-tools` prints the tools. The AI center of the shell
connects to it automatically (`ai.mcp.yozakura`).

| Tool | Read-only | Use |
|---|---|---|
| `config_search` | yes | find keys by words: `{"query":"rounded corners"}` |
| `config_schema` | yes | domains (no args) or every key of a domain/prefix with type, default, title, description, enum, range |
| `config_describe` | yes | one key in full: `{"key":"bar.layout.style"}` |
| `config_get` | yes | `{"key":"bar.position"}` or `{"domain":"bar"}` (whole effective domain) |
| `config_set` | no | `{"key":"bar.position","value":"bottom"}`; returns `changed: [{key, old, new}]`; same validation as the CLI; `force` skips enum/range |
| `presets_list` | yes | presets with domains, description and the active one |
| `preset_apply` | no | `{"name":"Neon Tokyo"}` |
| `preset_save` | no | `{"name":"Backup"}`, `domains`, `overwrite` |
| `preset_diff` | yes | `{"a":"current","b":"Sumi-e"}` |
| `preset_show` | yes | `{"name":"Sumi-e"}`, `against`: aspects, changed keys (with settings page), presets sharing each aspect |
| `preset_mix` | no | `{"name":"Blend","sources":{"layout":"Kaze","colors":"Neon Tokyo"}}` |
| `preset_duplicate` | no | `{"name":"Sumi-e","newName":"My ink"}` |
| `preset_rename` | no | `{"name":"My ink","newName":"Ink"}` (user presets) |
| `preset_delete` | no | `{"name":"Ink"}` -> trash, restorable |
| `wallpapers_list`, `wallpaper_set` | | wallpaper library / set (needs the running shell) |
| `windows_list`, `workspaces_list`, `window_focus`, `window_move_to_workspace`, `workspace_switch` | | compositor |
| `notification_send`, `notifications_list`, `dnd_set` | | notifications |
| `clipboard_read`, `clipboard_write`, `clipboard_history`, `screenshot` | | desktop |
| `media_status`, `media_control`, `volume_get`, `volume_set`, `shell_toggle` | | system |
| `shell_commands` | yes | the quick commands (launcher `>`): id, title, usage, argument spec |
| `specials_list` | yes | special workspaces with binds, apps and current window counts |
| `special_open`, `special_add`, `special_update`, `special_remove`, `special_app_add` | no | manage special workspaces: `{"name":"Chat","toggle":"SUPER+S","apps":["org.telegram.desktop"]}` |
| `shell_command` | no | run one: `{"command":"glass","arg":"0.6"}`, `{"command":"dnd"}` |
| `timer_list`, `reminder_list` | yes | timers (id, name, state, time left), stopwatch (elapsed, laps), reminders |
| `timer_start` | no | `{"duration":"10m","name":"tea"}`, `{"duration":"18:00"}`, `{"pomodoro":true,"duration":"50m","break":"10m"}` |
| `timer_control` | no | `{"id":"t3","action":"pause"}`; actions pause, resume, add (`"amount":"5m"`), reset, cancel, dismiss |
| `stopwatch_control` | no | `{"action":"lap"}`; start, pause, resume, toggle, lap, reset, status |
| `reminder_add`, `reminder_cancel` | no | `{"when":"in 20m","message":"stretch"}`, `{"when":"7:30pm"}`; cancel by id or message |
| `usage_summary` | yes | AI token usage/cost from the ledger: `{"range":"week","groupBy":"model","limits":true}` (same data as `yozakura usage`) |
| `task_list`, `task_status` | yes | coding tasks handed to CLI agents: status, runs, check results, summary, proposed commit message |
| `task_create` | no | `{"dir":"/home/me/proj","prompt":"Add tests for the parser","agents":["claude","codex"],"mode":"plan"}`: delegate coding work (worktree per run, verify loop); the user reviews and accepts it in the AI bar |
| `binds_search`, `binds_list`, `binds_check`, `binds_suggest` | yes | bind advisor: `{"query":"раскладка"}` -> results with a ready `action` ({id, args}); every bind with its source; is a combo free; free combos for an action |
| `binds_set`, `binds_remove`, `binds_undo` | no | `{"combo":"SUPER+F","action":"window.fullscreen"}` (confirm with the user first); writes `binds.json` only, returns `undo: {tool, args}` |
| `routines_list` | yes | saved routines with their steps |
| `routine_save`, `routine_run`, `routine_delete` | no | `{"name":"Night","steps":[{"kind":"tool","tool":"nightlight_set","args":{"enabled":true}},{"kind":"delay","ms":1000}]}` ("save this as a routine"); run returns a per-step report; delete always asks, and so do save/run of a routine with confirm-required steps (`app_close`, `binds_*`, `command.run`, `window.close`, quit), even in YOLO: the backend runs such a routine for an AI only after the user allowed that call (`routines.grant`) |
| `notes_search`, `notes_read` | yes | the Notes tab (`<data dir>-notes/index.json` + `notes/<id>.md|.html`) |
| `notes_create`, `notes_append` | no | `{"id":"Inbox","text":"buy milk","bullet":true}` (`create: true` makes a missing note); undo deletes the new note / restores the previous content (`notes_restore`) |
| `notes_delete`, `notes_restore` | no | delete a note (always asks; undo is `notes_restore` with its title and content); restore writes a note's whole content back, recreating it when deleted |
| `apps_find` | yes | installed `.desktop` apps by name/id |
| `app_launch`, `app_close` | no | `{"app":"firefox","workspace":3}`; close by window id/app/title (always asks; undo reopens) |
| `system_info`, `network_status`, `bluetooth_status`, `brightness_get` | yes | battery, CPU/RAM/GPU load and temps, disks, uptime; Wi-Fi/ethernet (+ nearby networks, `known`); paired Bluetooth devices; brightness per display |
| `bluetooth_connect`/`_disconnect`, `wifi_connect` (saved networks only), `wifi_toggle`, `audio_output_set` | no | each returns an undo |
| `brightness_set`, `nightlight_set`, `caffeine_set` | no | `{"percent":40}` / `{"delta":-10}`, `{"enabled":true,"temperature":3500}`, `{"enabled":true}`; undo restores |
| `displays_list` | yes | connected monitors with connector name, current mode, scale, rotation, VRR and every supported mode (`displays.list`) |
| `displays_apply`, `displays_confirm` | no | `{"outputs":[{"name":"DP-1","mode":"2560x1440@165","scale":1}]}`: applied live through the confirm session and **reverted after 15 s unless** `"keep":true` is passed (or `displays_confirm {"session":..., "keep":true}`); ask the user before keeping |
| `keyboard_get`, `keyboard_set` | yes / no | layouts, switch binding, active layout; `{"add":"ru"}`, `{"remove":"ru"}`, `{"switchBind":"super_space"}`, `{"next":true}` (undo included) |
| `focus_start`, `focus_stop` | no | focus mode (`ui.run focus:<min>` / `focus-stop`) |
| `focus_status` | yes | focus mode on/off, start, end and minutes left (the shell mirrors its state with `focus.set`; `focus.get` adds the timer's progress) |
| `providers_list`, `ollama_models` | yes | chat providers with a stored key + the local servers (Ollama, LM Studio): reachable or not, model ids (`providers.list`, free listing requests, keys never returned); installed Ollama models with capabilities (`providers.ollama.probe`, never loads a model) |
| `extras_list` | yes | the Extras catalog (apps and tools the shell can install): id, name, category, state (installed/missing/installing/failed/unavailable), source, reason; filters `category`, `state` (`extras.catalog` + `extras.status`) |
| `term_presets` | yes | fish prompt presets (id, name, lines, nerdFont) plus the setup state: enabled, engine, preset, installed engines and fish, login shell, foreign prompt init (`term.presets` + `term.status`) |
| `term_set` | no | `{"preset":"zen","engine":"starship"}` writes `terminal.*` and applies (`term.apply`); `{"enabled":false}` turns it off; the result's `todo` lists what is still missing (install the engine / fish through `extras_install`) |
| `extras_install` | no | `{"ids":["steam","discord"],"confirmMultilib":false}`: queues the installs (`extras.install`) and returns the jobs; always asks the user (it installs software and may prompt for root); `needs_confirm` means the pacman [multilib] repo must be enabled first, repeat with `confirmMultilib:true` only after the user agreed; `unavailable` lists a reason per id |
| `screen_look` | yes (asks: private) | screenshot returned as an MCP image block (`{"target":"window","scale":0.5}`); vision HTTP models get it as an image message |

Config and preset tools work on files and do not need the daemon; the others
talk to the running shell. Tools whose change can be reverted (timers,
reminders, stopwatch) return `"undo": {"tool": ..., "args": {...}}`: calling
that tool with those args undoes the change. Keys may be passed fully qualified (`"key":
"theme.roundness"`) or as `"domain"` + relative `"key"`.

**Agent etiquette.** Search or describe before you set; never invent keys.
Make the smallest change that fulfils the request. Before sweeping changes
(several domains, a preset), `preset_save` a backup and tell the user its
name. Report the old -> new values you changed.

## 4. Recipes: how to do X

Every recipe is a `yozakura config ...` / `yozakura preset ...` command; the
MCP equivalent is `config_set {"key": ..., "value": ...}`.

### Bar
1. **Move the bar to the bottom / left side**: `config set bar.position bottom` (`left`/`right` make it vertical).
2. **Floating islands instead of a continuous bar**: `config set bar.layout.style islands` (back: `classic`).
3. **Choose and order the bar modules**: `config set bar.layout.right presets,tools,systray,controls,battery,clock,power`. Module ids: `launcher workspaces layoutSelector pin presets tools systray controls battery clock power` (`config describe bar.layout.left`).
4. **Add / remove one module**: `config set bar.layout.left --add clock`, `config set bar.layout.right --remove systray`. An id listed in two groups (`left`, `right`, `drawer`) is shown only in the first.
5. **Tuck modules into the hover drawer**: `config set bar.layout.drawer --add systray` (remove it from its group first).
6. **Slimmer bar**: `config toggle bar.compact`.
7. **Auto-hide the bar**: `config set bar.pinnedOnStartup false` (reveal by touching the edge: `bar.hoverToReveal true`; strip size `bar.hoverRegionHeight`). Live pin toggle: `yozakura toggle bar`.
8. **Bar only on one monitor**: `config set bar.screenList DP-1` (empty list = all: `config set bar.screenList ""`).
9. **Clock with date / 12-hour**: `config set bar.clockShowDate true`, `config set bar.use12hFormat true`; no weather symbol in the clock (when the weather module is shown): `config set bar.moduleOptions.clock.showWeather false`.
10. **Screen frame around the desktop**: `config set bar.frameEnabled true`, `config set bar.frameThickness 10`, `config set bar.containBar true`.

### Theme and appearance
11. **Light / dark / OLED**: `config set theme.lightMode true`; dark: `false`; pure black: `config set theme.oledMode true`.
12. **Fonts**: `config set theme.font "Inter"`, `config set theme.fontSize 13`, `config set theme.monoFont "JetBrains Mono"`.
13. **Square or rounder corners**: `config set theme.roundness 0` (0..24); windows follow with `config set compositor.syncRoundness true`.
14. **No animations / faster animations**: `config set theme.animDuration 0` (or e.g. `250`).
15. **More transparent surfaces**: `config set theme.srBg.opacity 0.85`, `config set theme.srPopup.opacity 0.9`. The `sr*` keys are the surface variants (`srBg`, `srPopup`, `srBarBg`, `srPane`, `srFocus`, `srPrimary`, ...): `config list theme.srBarBg`.
16. **Glassiness (glass system)**: `config set theme.glass.amount 0.7` (0 solid .. 1 very glassy; `-1` = the preset's own look); per surface: `config set theme.glass.surfaces.bar.amount 0.3` (surfaces: `windows terminal popups bar notch dock sidebars lockscreen settings`); fine-tune: `config set theme.glass.advanced.blurSize 12`; off: `config set theme.glass.enabled false`. Everywhere in `theme.glass`, `-1` means inherit/auto and is accepted besides the range.
16b. **Surface effect (CRT / ink look)**: `config set theme.surfaceEffect crt` (`none`, `crt`, `ink`; shell surfaces only, never app windows), `config set theme.surfaceEffectOptions.intensity 0.4` (auto-lowered to keep text at WCAG AA); crt: `theme.surfaceEffectOptions.flicker false`; ink: `theme.surfaceEffectOptions.grain 0.8`, `theme.surfaceEffectOptions.brushHighlights false`.
16c. **Double hairline on the screen frame (shoji look)**: give the frame its own surface with a border: `config set theme.srFrame.inheritBg false`, `config set theme.srFrame.border '["secondary@0.5",1]'` (needs `bar.frameThickness` >= 3x the width + 2).
17. **Accent border on the bar**: `config set theme.srBarBg.border '["primary",2]'` (colour spec, width px).
18. **Gradient bar**: `config set theme.srBarBg.gradient '[["primary",0],["tertiary",1]]'`, `config set theme.srBarBg.gradientType linear`, `config set theme.srBarBg.gradientAngle 90`. Colour specs: palette roles (`primary`, `surface`, `overBackground`, ...), `#rrggbb`, or `role@0.5` for alpha.
19. **Softer shadows / no screen corners**: `config set theme.shadowOpacity 0.3`, `config set theme.enableCorners false`.
20. **Lock screen style**: `config set lockscreen.style paper` (`glass paper terminal aurora neon poster`; the SDDM login screen follows); light/dark version: `config set lockscreen.tone theme` (`style` = the style's own, `theme` = follow light/dark mode, `light`, `dark`); `config set lockscreen.blur 0.3` (`-1` = the style's own), `config set lockscreen.showVisualizer false`, `config set lockscreen.showMedia false`, `config set lockscreen.showStatus false`, `config set lockscreen.position top`.
21. **Change the palette (wallpaper colours)**: `yozakura wallpaper ~/Pictures/x.jpg -scheme scheme-expressive`; preview all schemes as JSON: `yozakura schemes ~/Pictures/x.jpg`.

### Windows (compositor)
22. **Gaps**: `config set compositor.gapsIn 4`, `config set compositor.gapsOut 10`.
23. **Window borders**: `config set compositor.borderSize 3`, `config set compositor.syncBorderColor false`, `config set compositor.activeBorderColor '["primary","tertiary"]'`.
24. **Window blur**: `config set compositor.blurEnabled true`, `config set compositor.blurSize 8`.
25. **Tiling layout**: `config set compositor.layout master` (`dwindle`, `master`, `scrolling`).
- **Smart gaps / dim**: `config set compositor.smartGaps true` (no gaps around a lone tiled window), `config set compositor.dimInactive true`, `config set compositor.dimStrength 0.15`.
- **Window animations (motion profile)**: `config set compositor.motionProfile springs` (`smooth`, `springs`, `snappy`, `gentle`, `stepped`, `sakura`, `off`; one file each in `config/motion/profiles/`). Tune with `compositor.motionDurationScale` (1 = as designed, 0.5 = twice as fast), `compositor.motionWorkspaceStyle` (`auto`/`slide`/`slidefade`/`fade`), `compositor.motionBorderLoop` (`auto`/`on`/`off`) + `motionBorderLoopSpeed`, and per animation `compositor.motionOverrides '{"windowsIn":{"speed":3,"style":"popin 70%"}}'`. With `compositor.motionShell` the profile also scales the shell's animations (`theme.animDuration` x profile scale).
- **Music-reactive border**: `config set compositor.borderPulse.enabled true` (`borderPulse.intensity` 0..1); only runs while a player is playing (Hyprland).

### Notch and live activities
26. **Notch at the bottom / floating island look**: `config set notch.position bottom`, `config set notch.theme island`.
27. **Open notch panels on click instead of hover**: `config set notch.expandOn click`.
28. **Hide the notch until hovered**: `config set notch.keepHidden true`.
29. **Custom idle text**: `config set notch.noMediaDisplay custom`, `config set notch.customText "夜桜"`.
30. **No audio visualizer**: `config set notch.visualizer false`.
31. **Activities as bar islands / off**: `config set bar.activities.presentation islands` (`notch`, `islands`, `off`); fewer at once: `config set bar.activities.maxVisible 2`.
32. **Stop tracking one source**: `config set bar.activities.sources.steam false` (`config list bar.activities.sources`).

### Dock, workspaces, desktop
33. **Dock on/off, side, size**: `config set dock.enabled false`, `config set dock.position left`, `config set dock.iconSize 32`.
34. **Dock inside the bar (taskbar)**: `config set dock.theme integrated`.
35. **Workspace indicator**: `config set workspaces.shown 6`, `config set workspaces.showNumbers true`, `config set workspaces.numeralStyle kanji` (`config describe workspaces.numeralStyle` lists styles), `config set workspaces.dynamic true`; active indicator shape: `config set workspaces.indicatorStyle bracket` (`pill underline dot brush bracket`).
36. **Wallpaper transition**: `config set desktop.wallpaperTransition fade`, `config set desktop.wallpaperTransitionDuration 600`.
37. **Extra wallpaper folder**: `config set desktop.wallpaperFolders --add /home/me/Pictures/Walls`.
38. **Depth clock behind the wallpaper subject**: `config set desktop.depthClock true`, `config set desktop.depthClockStyle poster`, `config set desktop.depthClockPosition right`.
39. **Desktop icons**: `config set desktop.enabled true`.
40. **Overview grid**: `config set overview.rows 3`, `config set overview.columns 4`.

### System, AI, misc
41. **Terminal used by the shell**: `config set general.terminal foot`.
42. **UI language**: `config set system.language ru` (`auto` = system locale).
43. **Weather**: `config set weather.location "Tokyo"`, `config set weather.unit F`.
44. **Launcher prefixes**: `config set prefix.clipboard cb`.
45. **AI bar**: two spaces, switched in the header (Ctrl+1 / Ctrl+2, binds `ai-chat` / `ai-code`): **Assistant** (any engine; CLI agents run in the backend `assistant` mode from `$HOME` with the yozakura MCP and ask before commands/file writes) and **Code** (CLI agents in a project folder: project bar, detailed transcript, changes, gear). Each space keeps its own engine, conversation and history (`GlobalStates.aiSpace`, persisted). Choose the Assistant engine with `config set ai.defaultModel agent:codex` (or an exact API/local model ID) and the Code agent with `config set ai.agents.defaultAgent codex`; look and behaviour live in `ai.appearance.*`, `ai.behavior.*`, `ai.strip.*` (settings → AI). Position with `config set ai.sidebarPosition left`; voice: `config set voice.activation toggle`. The header cycles compact → wide → fullscreen (Ctrl+W) without changing the saved sidebar width. History combines saved chats and agent sessions; switching keeps background tasks, drafts and scroll positions. The model picker (Ctrl+K) lists each CLI agent as a group of its own models (`agents.models`; Claude haiku/sonnet/opus, Codex gpt-5.x, OpenCode provider/model, plus a manual id field); one click picks engine + model. The last pick per space (engine, agent model; effort per model) is persisted in StateService (`aiEngines`, `aiAgentModels`, `aiModelEfforts`, see `modules/services/ai/EngineMemory.qml`) and used by new chats, restarts, Quick Ask (when `ai.quickAsk.model` is empty) and Code tasks (unless `ai.tasks.defaultAgents` is set); `ai.defaultModel` is only the initial engine, or wins when changed after the pick. Agent settings show the installed CLI's model/effort catalog; launch settings can change while idle. Selection results offer explicit Copy/Continue. OpenCode ACP currently rejects the restricted Quick Ask profile rather than silently switching providers.
    **Model, effort, context** (AI bar strip `◆ engine · model ▾  level ▾ … 62k/200k`): the reasoning effort is picked inline and remembered per model (`StateService` `aiModelEfforts`; `config set ai.effort.defaultLevel high` for untouched models, `auto` sends nothing); levels map per family in `modules/services/ai/Effort.js` (CLI agents use their own catalog values). Capabilities and windows come from `assets/ai/models.json` and the backend Ollama probe (`providers.ollama.probe`); Ollama chats send `num_ctx` (`ai.ollama.numCtx`). Unknown windows: `ai.context.overrides`. HTTP chats compact older turns into a summary (Compact button from `ai.context.warnAt`, automatic at `ai.context.autoCompactAt` when `ai.context.autoCompact`; `ai.context.keepTurns`, `ai.context.compactModel`); agents report `usage.contextTokens/contextWindow` on `done` events and compact themselves.
    **Providers** (Connect sheet: picker footer "Connect provider", "not connected" rows, the Assistant "Connect a model" CTA, Settings → AI providers, onboarding): pick a preset (`modules/services/ai/ProviderPresets.js`), enter the key and/or base URL, Test (`providers.test`, free listing; Ollama: `providers.ollama.probe`), Save. Keys live in the KeyStore; Ollama/LM Studio need no key and count as connected while reachable (`ai.ollama.endpoint`, `ai.lmstudio.endpoint`, re-probed every `ai.providers.probeInterval` s while the bar is open). Rules in `ProviderConnect.js`, actions in `ProviderSetup.qml` (`Ai.providers`), UI in `modules/aicenter/providers/`. Requests: `ai.providers.timeout`, `ai.providers.retries`, `ai.providers.customHeaders` (Custom endpoint), `ai.providers.openrouterAttribution`, `ai.ollama.keepAlive`; hide a provider with `ai.providers.hidden`.
46. **Pomodoro length**: `config set system.pomodoro.workTime 1800` (seconds).
47. **Pomodoro, timers, focus**: `config set system.pomodoro.workTime 1800` (seconds); notch look `system.timers.notchStyle ring|text`, `system.timers.showSeconds`, alarm `system.timers.sound`/`soundFile`/`alarmRepeat` (0 = until stopped); focus mode length `system.focus.minutes` (+ `dnd`, `hideBadges`, `summary`); clock click `system.timers.clockClick popup|timers`; launcher prefix `prefix.timers` ("t 10m tea"). Binds (group "Utilities"): `yozakura run timer-input|quick-note|timers|stopwatch-toggle|focus-toggle|timer-stop`, `yozakura run 'timer:10m tea'`; defaults SUPER+SHIFT+T (timer input) and SUPER+SHIFT+N (quick note to the Notes "Inbox").
48. **Lighter on the GPU**: `config set performance.rotateCoverArt false`, `performance.windowPreview`, `performance.blurTransition`.
49. **Turn a group off in one go**: `config set bar.activities '{"enabled":false}'`.
50. **Notifications as corner toasts**: `config set notifications.presentation corner` (`notch` = born from the notch, `auto` = by the preset's bar style), `config set notifications.position bottom-right`, `config set notifications.timeout 8000`, `config set notifications.maxVisible 2`, only on one monitor: `config set notifications.screens '["DP-1"]'`.
51. **Per-app notification rules**: `config set notifications.rules '[{"app":"discord","action":"mute"},{"app":"Signal","action":"priority"}]'` (actions: `mute`, `priority`, `alwaysShow`, `soundOff`; `*` wildcards).
52. **Do Not Disturb at night**: `config set notifications.dnd.schedule '{"enabled":true,"from":"22:00","to":"07:00","days":[0,1,2,3,4,5,6]}'`; right now: `config set notifications.dnd.enabled true` (or the `dnd_set` MCP tool).
53. **Stop theming an app / kitty font**: `config set apps.theming.discord false` (gtk, qt, kitty, discord, spicetify, telegram, firefox, papirus, nvim, sddm); `config set apps.kitty.font "JetBrains Mono"`, `config set apps.kitty.fontSize 12`.
54. **Install Steam, Discord, Claude Code ... from the shell**: `yozakura extras list [--category ai]` shows the catalog with each entry's state (installed / missing / installing / failed / unavailable + reason); `yozakura extras install steam discord claude-code` queues them (requirements first, installed ones skipped; installs run one after another, system packages ask for the password through polkit; progress streams until done); `yozakura extras status <id>`. Steam and other 32-bit software need the pacman `[multilib]` repo: the install fails with `needs_confirm` until you pass `--yes-multilib`. Over MCP: `extras_list`, `extras_install` (always asks the user). Pull an Ollama model or set the login shell through IPC (`extras.ollamaPull {model}`, `extras.setLoginShell {shell}`); a failed install can be retried after a system upgrade (`extras.upgradeAndRetry {job}`). Catalog: `assets/catalog/extras.json`.
55. **Make my terminal prompt pretty**: the fish prompt (Starship or oh-my-posh) is drawn with the shell palette from 14 Nerd Font presets and follows theme changes by itself. `yozakura term list` shows the presets, `yozakura term preview <preset> [--engine ohmyposh]` draws one (exact when the engine is installed, otherwise an approximation), `yozakura term set <preset> [--engine starship|ohmyposh]` turns it on (writes `terminal.json`, the engine config in `~/.config/yozakura/` and the owned fish file `~/.config/fish/conf.d/yozakura.fish`; `config.fish` is never touched), `yozakura term status` reports what is missing, `yozakura term off` removes the fish file. The prompt stays off until a preset is chosen. If the engine or fish is missing install it first (`yozakura extras install starship` / `oh-my-posh` / `fish`); if fish is not the login shell the prompt only shows inside fish (`extras.setLoginShell {shell}`); if the user's own `config.fish` already runs `starship init fish` / `oh-my-posh init fish`, theirs wins. Other terminal keys (`config search terminal`): `terminal.greeting` (none | fastfetch), `terminal.padding`, `terminal.cursorShape`, `terminal.cursorBlink` (kitty), font in `apps.kitty.*`, opacity in `theme.terminalOpacity`. Over MCP: `term_presets`, `term_set` (`{"preset":"cherry-blossom","engine":"starship"}` or `{"enabled":false}`). Presets: `assets/terminal/prompts/*.json`, a new one is one file plus `term.prompt.<id>.desc` in the translations; the preset format and renderers are in `backend/pkg/termlook`. The `terminal` preset aspect carries the look (prompt, greeting, padding, cursor); `terminal.enabled` and `terminal.engine` are machine-local, so a preset never switches the prompt on/off or changes the engine.

### Presets
56. **Try a preset safely**: `preset save Backup`, `preset apply "Neon Tokyo"`; back: `preset apply Backup`.
57. **What would a preset change?** `preset diff current "Kōyō"`.
58. **Share a look**: `preset export current look.json`; on the other machine `preset import look.json --name Shared` then `preset apply Shared`.
59. **Save only the colours**: `preset save "Only colors" --domains theme`.
60. **Try for a moment**: `preset try CRT`, then `preset try --keep` or `--revert` (the settings studio counts down 10 s and reverts by itself).
61. **Combine presets**: `preset mix Blend --layout Kaze --colors "Neon Tokyo" --windows CRT --desktop Sumi-e --lockscreen defaults`.
62. **Customise a built-in**: `preset duplicate "Neon Tokyo" Mine`, `preset edit Mine`, change settings, `preset edit --save`.
63. **Where does a preset differ?** `preset show Mine --against "Neon Tokyo"`.
64. **Undo everything in one domain**: `config reset compositor --yes`.

### Special workspaces
65. **A scratchpad for chat on Super+S**: `special add Chat --template chat --toggle SUPER+S --send SUPER+ALT+S` (settings: Special workspaces; onboarding offers templates). Hyprland only; elsewhere the page shows a notice and nothing runs.
66. **Launch apps when it opens**: `special app add Chat org.telegram.desktop` (class from StartupWMClass, command from Exec; edit with `--match`/`--command`). Already running elsewhere: `--if-running move` pulls it in, default leaves it. Never launched twice while it maps its window (`specials.launchTimeout`).
67. **Always open an app there**: `--rule` (Hyprland window rule `workspace special:<name> silent`).
68. **Start apps hidden at login**: `special set Chat --preload on` (`specials.preloadDelay`).
69. **Bind conflicts**: the special binds are rows of the keybinds model (cheatsheet, editor conflicts); `special add/set` prints clashes with `binds.json`.
70. **Turn the feature off** (keeps the list): `config set specials.enabled false`.
71. **Set my monitor to 165 Hz**: `display list` (connector name and modes), then `display set DP-1 --mode 2560x1440@165`, answer `y` within 15 s (or add `--yes`). MCP: `displays_apply {"outputs":[{"name":"DP-1","mode":"2560x1440@165"}]}` reverts after 15 s unless the user confirmed and you pass `"keep":true` (or `displays_confirm`).
72. **Add Russian layout / change the switch key**: `keyboard add ru` (`keyboard add us:intl` for a variant), `keyboard switch-bind super_space`, `keyboard list`; same as `config set keyboard.layouts ...` but with XKB-catalog checks. MCP: `keyboard_set {"add":"ru"}`.
73. **Rotate or scale a monitor**: `display set HDMI-A-1 --rotate 90 --scale 1.5`; `--vrr on` for adaptive sync, `--pos 2560x0` to place it right of a 2560 px wide monitor.
74. **Install on a fresh machine / preview the installer**: `install.sh` installs only the core (shell, one compositor, a login screen), asks which compositor (Hyprland, niri or Mango; `--compositor NAME`), shows the plan, asks once and offers a reboot into the setup wizard (`--reboot` / `--no-reboot`; without a terminal it uses the defaults and does not reboot). `install.sh --dry-run` walks the whole flow (questions, plan, every step) saying what it would do, with no sudo and no changes. Everything else (apps, AI, voice, terminal prompt) is chosen in the wizard or later with `yozakura extras`. Code: `install.sh`, `tests/install-sh.test.py` (stubbed `pacman`/`sudo`).
75. **Search only my routines in the launcher**: type `@` (`prefix.routines`), `@night` filters by name or keyword; the list is empty when no routine exists. Without the prefix routines are the first provider of mixed results (`prefix.launcher.order`), 3 at most. Code: `modules/widgets/launcher/providers/RoutinesProvider.qml`.
76. **Try the wizard without touching the system**: `yozakura onboarding --dry-run [--keep]` (see Quick commands above; rules for adding a wizard call in `modules/onboarding/AGENTS.md`). Use it instead of resetting `general.onboardingDone` on a real setup.
77. **Third-party app is not themed** (kitty, Ghostty, foot, Discord, Qt ...): the daemon `apphooks` service wires them to the generated theme files, idempotently and never into files the user manages elsewhere (Nix store, unparsable): IPC `apphooks.status | ensure {ids} | apply {id} | revert {id}`; states connected / disconnected / absent / managed / error. Add an app in `backend/pkg/apphooks/` (one file, register in `apphooks.go`) and a generator under `modules/theme/` if it needs a file; `modules/services/AppHooksService.qml` is the shell side. `backend/pkg/envclean` deduplicates `XDG_DATA_DIRS`, `PATH` ... at startup and for every child the daemon starts (a compositor config that prepends on each reload otherwise grows them without bound).

### Keybinds
Keybinds live in `~/.config/yozakura/binds.json` (hot-reloaded), edited in
Settings (`yozakura run config`, Input page). `binds.json` has two parts:
`"yozakura"` (core binds: `{"<name>": {"modifiers": ["SUPER"], "key": "A",
"action": {"id": "yozakura.<name>", "args": {}}}}`) and `"custom"` (a list of
`{name, enabled, keys: [{modifiers, key}], actions: [{id, args, layouts}]}`).
The action ids are catalogued in `config/KeybindActions.js`
(`ACTION_CATALOG`; `make schema` exports it with the core binds and every
translation to `assets/schema/bind-actions.json` for the backend). Prefer
`yozakura binds` / the `binds_*` MCP tools: they search actions in plain
words (synonyms, Russian), check conflicts against the shell, special
workspaces and the compositor's own binds (`yozd config list-binds`:
`hyprctl binds -j` on Hyprland, a best-effort config parse on niri and
MangoWC), suggest free combos and write `binds.json` atomically with an undo
token. Without them, edit the file with `jq` (keep a copy), e.g. to move the
assistant to Super+I:

```bash
f=~/.config/yozakura/binds.json; cp "$f" "$f.bak"
jq '.yozakura.assistant.key = "I"' "$f.bak" > "$f"
```

To open an installed app use the action `{"id": "apps.launch", "args":
{"app": "<desktop id>"}}` (e.g. `firefox`, `org.gnome.Nautilus`, the file name
without `.desktop`): it renders to `yozakura launch <id>`, which starts the app
exactly like the launcher (`gio launch <file>`), instead of a `command.run`
with a shell command. Two binds may share a combo (Hyprland runs both); the
settings page marks them as conflicts but never blocks or overwrites one.

Defaults (only for a new `binds.json`; an existing file keeps its combos):
Super+Q closes the window, Super+T opens the terminal (`general.terminal`,
action `yozakura.terminal` / `yozakura run terminal`), Super+Alt+T opens
tmux sessions; `tests/keybinds.test.cjs` checks that no two defaults share a
combo.

## 5. Where the code lives

| Feature | Code | Config | Tests |
|---|---|---|---|
| Bar layout, modules | `modules/bar/BarContent.qml`, `BarLayout.js`, `BarModuleSlot.qml` | `bar.layout.*` | `tests/bar-layout.test.cjs` |
| Islands bar | `modules/bar/BarIslands.qml`, `BarIsland.qml`, `IslandShape.qml` | `bar.layout.style` | |
| Bar sizes | `modules/theme/BarMetrics.qml` | `bar.compact` | |
| Clock / weather | `modules/bar/clock/` | `bar.clockShowDate`, `weather.*` | |
| Workspaces | `modules/bar/workspaces/`, `WorkspaceNumerals.js` | `workspaces.*` | `tests/workspace-*.test.*` |
| Live activities | `modules/services/activities/`, `modules/bar/activities/` | `bar.activities.*` | `tests/activities.test.cjs`, `tests/transfers.test.cjs` |
| Notch | `modules/notch/`, `modules/widgets/defaultview/` | `notch.*` | `tests/notch-*.test.*` |
| Notch panels | `modules/widgets/defaultview/panels/NotchPanels.js` | | `tests/notch-panels.test.cjs` |
| Dock | `modules/dock/`, `modules/bar/IntegratedDock.qml` | `dock.*` | |
| Theme, colours | `modules/theme/Colors.qml`, `Styling.qml`, `config/ColorSpec.js` | `theme.*` | `tests/palette-crossfade.test.py` |
| App themes (kitty, GTK, ...) | `modules/theme/*Generator.qml` | `theme.terminalOpacity` | `tests/theme-generators.test.py` |
| Compositor appearance | `modules/services/CompositorAppearance.js`, `CompositorTomlWriter.qml` | `compositor.*` | `tests/compositor-*.test.*` |
| Motion profiles | `config/motion/` (registry + resolver), `modules/services/CompositorMotion.qml`, `backend/pkg/svc/compositor/motion.go` | `compositor.motion*` | `tests/motion-profiles.test.cjs`, `motion_test.go` |
| Music-reactive border | `modules/services/BorderPulse.{qml,js}` | `compositor.borderPulse.*` | `tests/border-pulse.test.cjs` |
| Desktop, depth clock | `modules/desktop/`, `clockstyles/ClockStyleRegistry.js` | `desktop.*` | `tests/clock-styles.test.cjs`, `tests/depth-clock.test.py` |
| Desktop widgets | `modules/desktop/widgets/` (`WidgetRegistry.js`, `types/`) | `desktop.widgets*` | `tests/desktop-widgets.test.{cjs,py}` |
| Wallpapers | `modules/widgets/dashboard/wallpapers/` | `desktop.wallpaper*` | `tests/wallpaper-*.test.*` |
| Launcher | `modules/widgets/launcher/` | `prefix.*` | |
| Settings window | `modules/settings/` (schema-driven) | | `tests/settings-schema.test.cjs`, `tests/settings-ui.test.py` |
| Presets | `backend/pkg/presets` (aspects registry: `aspects.go`), settings studio `modules/settings/presets/` + `modules/settings/store/PresetStudio.qml`, quick switcher `modules/services/PresetsService.qml` (all run `yozakura preset`) | `tools/render/presets_render.py` | `backend/pkg/presets/*_test.go`, `tests/preset-studio*.test.*` |
| AI bar | `modules/aicenter/` (`transcript/` one transcript for every engine, `assistant/`, `code/`, `header/`, `composer/`), `modules/services/Ai.qml`, `modules/services/ai/` (`SpaceState.qml` spaces), `backend/pkg/svc/agents` | `ai.*` | `tests/ai-*.test.*` |
| Voice | `modules/services/voice/`, `backend/pkg/svc/voice` | `voice.*` | `tests/voice*.test.*` |
| Terminal prompt (fish + Starship / oh-my-posh) | `backend/pkg/termlook` (presets, renderers, writer, fish hook, preview), `backend/pkg/svc/term` (IPC, palette watcher), `assets/terminal/prompts/*.json`, `config/defaults/terminal.js`, kitty keys in `modules/theme/KittyGenerator.qml`, CLI `cmds_term.go`, MCP `term_tools.go`, `goodbye` removes the fish file | `terminal.json` | `backend/pkg/termlook/*_test.go`, `backend/pkg/svc/term/service_test.go`, `cmds_term_test.go`, `term_tools_test.go`, `tests/theme-generators.test.py` |
| Extras and apps catalog | `assets/catalog/extras.json`, `backend/pkg/svc/extras` (catalog/detect/plan/queue/progress, IPC `service.go`, helper choice `errors.go`), privileged helper `backend/pkg/sysinstall` + `yozakura sys` (`cmds_sys.go`), CLI `cmds_extras.go`, MCP `extras_tools.go`; post hooks via `extras.RegisterPost` (daemon wiring) | none (state is detected) | `backend/pkg/svc/extras/*_test.go`, `cmds_extras_test.go`, `extras_tools_test.go` |
| Timers, stopwatch, reminders, focus | `backend/pkg/svc/timers` (parser `parse.go`/`quick.go`, state machine `engine.go`, IPC `methods.go`), CLI `cmds_timers.go`, MCP `timer_tools.go`; shell: `modules/services/TimersService.qml` (thin client), `FocusMode.qml`, `QuickNote.qml`, `UtilityCommands.qml`, `modules/services/timers/*.js`, notch `activities/TimerActivity.qml` + `panels/Timer*`, `AlarmPanel`, `QuickInputField`, launcher `providers/TimersProvider.qml` | `system.pomodoro.*`, `system.timers.*`, `system.focus.*`, `prefix.timers` | `backend/pkg/svc/timers/*_test.go`, `timer_tools_test.go`, `cmds_timers_test.go`, `tests/timers-*.test.*`, `tests/timer-panels.test.py`, `tests/notify-request.test.cjs` |
| Displays and keyboard | `backend/pkg/svc/displays` (confirm session, conflicts), `backend/pkg/svc/keyboard` (XKB catalog, active layout), CLI `cmds_display.go`/`cmds_keyboard.go`, MCP `display_apply_tools.go`/`monitor_layout.go`/`keyboard_tools.go`; shell `modules/services/DisplaysService.qml`, settings `modules/settings/displays/`, `modules/settings/keyboard/` | `displays.monitors`, `keyboard.*` | `backend/pkg/svc/displays/*_test.go`, `cmds_display_test.go`, `cmds_keyboard_test.go`, `display_apply_tools_test.go` |
| Installer and onboarding dry run | `install.sh` (compositor choice, `--dry-run`, reboot), `backend/cmd/yozakura/cmds_onboarding_dryrun.go`, `onboarding-dryrun.qml`, `modules/globals/DryRun.qml`, `modules/services/DryRunMethods.js` + `DryRunBackend.js` | `general.onboardingDone` | `tests/install-sh.test.py`, `tests/onboarding-dryrun.test.py`, `tests/dryrun-backend.test.cjs` |
| Exclusive mode (Hyprland) | `backend/pkg/exclusive`, `backend/pkg/svc/exclusive`, CLI `cmds_exclusive.go`, `modules/services/ExclusiveService.qml`, `modules/settings/system/ExclusiveCard.qml` | none (backups in `~/.local/share/yozakura/backups/`) | `backend/pkg/exclusive/*_test.go`, `cmds_exclusive_test.go`, `tests/exclusive-ui.test.py` |
| App hooks and env cleanup | `backend/pkg/apphooks` (per-app hooks), `backend/pkg/svc/apphooks` (IPC), `backend/pkg/envclean` (PATH-like vars), `modules/services/AppHooksService.qml` | `apps.theming.*` | `backend/pkg/apphooks/*_test.go`, `backend/pkg/envclean/envclean_test.go` |
| Lock screen | `modules/lockscreen/` | `lockscreen.*` | `tests/lockscreen.test.py` |
| Keybinds | `config/KeybindActions.js`, `modules/services/GlobalShortcuts.qml` | `binds.json` | |
| Routines | `backend/pkg/svc/routines` (model/run/IPC), `pkg/daemon/routines.go`, CLI `cmds_routine.go`, MCP `routine_tools.go`; shell `modules/services/RoutinesService.qml`, `modules/routines/RoutineModel.js`, settings `editors/RoutinesEditor.qml` + `editors/routines/`, launcher `providers/RoutinesProvider.qml`, keybind slots `modules/keybinds/RoutineSlots.js` | `routines.json` | `backend/pkg/svc/routines/*_test.go`, `tests/routines.test.cjs`, `tests/routines-ui.test.py`, `tests/ai-automation-routine.test.py` |
| AI automation tools | `backend/pkg/mcp/yozakura/{note,app,sysinfo,connection,display,focus,vision}_tools.go`; chat side `modules/services/ai/ToolMedia.js` (undo + images), `ToolHints.js` (system prompt hints), `Permissions.js` (`CONFIRM`) | | `*_tools_test.go`, `tests/ai-tool-media.test.cjs` |
| Bind advisor | `backend/pkg/binds` (search, list, check, suggest, set/remove/undo), catalog `tools/schema/bind_actions.cjs` -> `assets/schema/bind-actions.json`, CLI `cmds_binds.go`, MCP `bind_tools.go`, yozd `Config.ListBinds` (`pkg/yozd/server/binds.go`, `ipc/*/binds.go`) | `binds.json` | `backend/pkg/binds/binds_test.go`, `tests/bind-actions.test.cjs` |
| Settings catalog | `tools/schema/`, `config/meta/`, `backend/pkg/catalog` | | `tests/schema-catalog.test.cjs`, `backend/pkg/catalog/*_test.go` |
| CLI | `backend/cmd/yozakura/` (`cmds_config.go`, `cmds_preset.go`, `cmds_completion.go`) | | `cmds_config_test.go` |
| MCP tools | `backend/pkg/mcp/yozakura/` (`config_tools.go`, `preset_tools.go`, ...) | | `tools_test.go` |
| Special workspaces | `modules/specials/` (`Specials.js` logic, `SpecialsService.qml` launch/move/rename/preload), settings `modules/settings/editors/SpecialsEditor.qml` + `editors/specials/`, onboarding `StepSpecials.qml`, dashboard `widgets/SpecialsPanel.qml`, launcher `providers/SpecialsProvider.qml`, `backend/pkg/specials` (CLI `cmds_special.go`, MCP `special_tools.go`), yozd `System.ExecuteIn` + `[[window_rules]] workspace` | `specials.*` (global, `catalog.LocalDomains`) | `tests/specials.test.cjs`, `tests/specials-ui.test.py`, `backend/pkg/specials/*_test.go`, `presets/specials_test.go` |

## 6. Extending Yozakura

Principles: small single-purpose files, registries (adding a thing = one file
+ one entry), no hard-coded colours/sizes (`Colors.*`, `Styling.*`,
`BarMetrics`, `Config.*`), everything configurable and carried by presets,
working on every preset/edge/light-dark/roundness 0..24/`animDuration 0`.

**Add a setting.**
1. Default in `config/defaults/<domain>.js` (the validator drops keys without a
   default); `make schema` regenerates the typed adapter
   `config/adapters/<Domain>Adapter.qml` (add a type to
   `config/meta/AdapterTypes.js` for whole numbers or free-form objects); add it
   to the `GlobalStates` snapshot list when a settings panel edits it.
2. Declare it in `modules/settings/schema/<category>.js` (type, label,
   description, options/min/max, `visibleWhen`) and add the strings to
   `translations/{en,es,ru}.json` (see `modules/settings/AGENTS.md`).
3. If the settings UI does not state its allowed values (custom editor, no
   entry), describe it in `config/meta/<domain>.js` (description, `enum`,
   `min`/`max`, `items`; shared lists in `config/meta/Enums.js`).
4. `make schema` (regenerates `assets/schema/`; the `schema-fresh` audit
   fails until you do). The CLI, completion and MCP pick it up with no code.

**Add a bar module.** A component in `modules/bar/`, one entry in the
`BarModuleSlot.qml` registry and its id in `BarLayout.js` `MODULE_IDS`, the
presentation (icon, label key) in `modules/settings/BarModules.js`, strings,
then `make schema` (the id joins the allowed items of `bar.layout.*`).
Handle horizontal and vertical orientation and both bar styles.

**Add a quick command** (launcher `> name`, `yozakura cmd`, MCP
`shell_command`): one entry in `assets/commands/commands.json` (`id`, `icon`,
`title`/`description` translation keys, `keywords`, optional `arg`
{kind none|enum|number|preset}, and `run`: `{"ui": "<GlobalShortcuts run
command>"}`, `{"toggle": "bar"}`, `{"cli": ["preset", "apply", "{arg}"]}` or
`{"config": "<catalog key>", "map": {...}}`) plus the strings. A `ui` command
must exist in `GlobalShortcuts.qml` `run()` (checked by
`backend/pkg/commands` tests).

**Add a notch panel.** A `NotchPanel` QML file in
`modules/widgets/defaultview/panels/` and one entry in `NotchPanels.js`
`PANELS` (see that directory's `AGENTS.md`).

**Add a clock style.** One `modules/desktop/clockstyles/<Name>Clock.qml`
extending `ClockStyle` and one entry in `ClockStyleRegistry.styles` (+ a
`labelKey` translation); `make schema` adds it to the allowed values of
`desktop.depthClockStyle`. A preset picks the clock colour with
`desktop.depthClockInk` (`auto` or a palette role).

**Add a desktop widget type.** One `modules/desktop/widgets/types/<Name>Widget.qml`
extending `DesktopWidget` (uses `options`, `ink`, `k`, polls only while
`active`) and one entry in `WidgetRegistry.types` (size, minSize, options
shown generically in settings) + its label translations; `make schema`
adds the type to `desktop.widgets[].type`. Place widgets with
`yozakura config set desktop.widgets '[{"type":"note","x":0.7,"y":0.1,"w":0.15,"h":0.2}]'`
(x/y/w/h are fractions of the screen; `monitor` "" = first screen) or
interactively: `yozakura run desktop-edit` toggles edit desktop mode.

**Add a lock screen style.** One `modules/lockscreen/styles/<Name>Style.qml`
extending `LockStyle` (slots: backdrop, clock, passwordField, mediaCard,
status; see `modules/lockscreen/AGENTS.md`) and one entry in
`LockStyleRegistry.styles` (+ `labelKey`/`descKey` translations); `make
schema` adds it to `lockscreen.style`, the settings gallery shows it live and
`tests/lockscreen.test.py` runs the auth checks against it. Mirror it for the
login screen in `assets/sddm/yozakura/styles/`.
**Add a motion profile.** One `config/motion/profiles/<id>.js` (curves
named `<id>...`, Hyprland animation-tree leaves, border loop, shell scale and
easing; format in `config/motion/MotionProfiles.js`), one entry in its
`ORDER`, `prefs.motion.profile.<id>[.desc]` strings, then `make schema` (the
id joins the allowed values of `compositor.motionProfile`) and
`UPDATE_FIXTURES=1 node --test tests/motion-profiles.test.cjs` if you changed
a profile the Go parity fixture uses.

**Add a numeral system.** One entry in `modules/bar/workspaces/WorkspaceNumerals.js` `SYSTEMS`, then `make schema`.

**Add a workspace indicator style.** One QML file in `modules/bar/workspaces/indicators/` (gets `indicator`: box, `vertical`, `slotSize`, `occupied`, ...) + one entry in `IndicatorStyles.js` (`filled`: label on the fill or accent colored), translation `prefs.indicator.<id>`, then `make schema`.

**Add a surface effect.** One QML file in `modules/components/surfaceeffects/` (overlay drawn over shell surface backgrounds; optional highlight fill) + one entry in `SurfaceEffects.js` (`options` it reads, worst-case `overlay` alphas for the WCAG clamp), translations `prefs.effects.<id>` / `.desc`, then `make schema`. Shaders: `qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o x.frag.qsb x.frag`.

**Add a bundled UI font.** Subset it (`pyftsubset`, Latin + Cyrillic/kana
as the family has them) into `assets/fonts/ui/<Dir>/` with its OFL/Apache
licence and add one entry to `modules/theme/BundledFonts.js`;
`FontRegistry.qml` loads it at startup so `theme.font` can name it.

**Add a built-in preset.** A directory `assets/presets/<Name>/` with the
domain files it sets (`bar.json`, `theme.json`, ...; never the private domains `system`, `ai`,
`prefix`, `weather`, `notifications`, `apps`, `general`, `specials`, nor machine-local
keys: secrets, commands, endpoints, personal paths, see config/meta `local`), optionally `wallpaper.json` (`matugenScheme`), and
`info.json` (`author`, `authorUrl`, `description`, optional `follows`: keys
the preset leaves to the user, e.g. `["theme.lightMode"]` keeps the live
light/dark mode when it is applied). A file replaces the whole live domain
file and the shell fills the keys it lacks with defaults, so keep files to
the keys that define the look. Layouts go in `bar.panels`. Name only fonts
that are bundled (`modules/theme/BundledFonts.js`) or installed by the
installers (`tests/bundled-fonts.test.cjs` checks every built-in preset). Easiest: build the look live, `yozakura preset save <Name>`,
copy `~/.config/yozakura/presets/<Name>/` into `assets/presets/`.
`backend/pkg/catalog` tests validate every built-in preset against the
catalog.

**Add an activity source.** See `modules/services/activities/AGENTS.md`.

**Add a settings category.** `modules/settings/schema/<id>.js` + import in
`Categories.js` (see `modules/settings/AGENTS.md`).

**Add an MCP tool.** `define(...)` in a `backend/pkg/mcp/yozakura/*_tools.go`
file, register its group in `Tools()` (`tools.go`), add read-only tools to
`yozakuraReadOnly` in `backend/pkg/svc/agents/policy.go`, test in
`tools_test.go`.

**Add a CLI command.** A `cmds_<name>.go` in `backend/cmd/yozakura`
(commands that only touch files go in the first switch of `main.go`, before
migration and daemon checks), a line in `showHelp`, `topCommands` in
`cmds_completion.go`, tests next to it.

## 7. Definition of done

A change is done when (root `AGENTS.md` has the full list):

1. `make check` is green (parse, qmllint baseline, qmlformat, go vet/staticcheck/gofmt, shellcheck, ruff, audits including `settings-schema`, `schema-fresh`, `brand-literals`, and every test).
2. No new lint findings; never refresh a baseline to hide your own.
3. Config keys registered everywhere (defaults, snapshot lists) and the catalog + adapters regenerated (`make schema`).
4. Strings translated in every `translations/*.json`.
5. Small focused files (< 400 lines, never grow one over 800); no dead code.
6. Logic tested (`tests/*.test.cjs`, `tests/*.test.py`, Go `_test.go`).
7. Works with every preset and layout: classic/islands, any edge, frame on/off, light/dark/OLED, roundness 0..24, `animDuration 0`, any font, several monitors.
