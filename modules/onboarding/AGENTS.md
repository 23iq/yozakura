# AGENTS.md: modules/onboarding/

## OVERVIEW
First-run setup wizard: a full-screen glass card (Overlay layer, namespace
`<app>:onboarding`) in 8 steps (OnboardingSteps.js): welcome + language,
displays + keyboard, look (preset + wallpaper tabs), terminal (app, fish
prompt, login shell), apps, AI + voice, an interactive keybind tour and a
summary.

## STRUCTURE
```
onboarding/
├── OnboardingWindow.qml   PanelWindow on the screen it opened on (shell.qml Loader)
├── OnboardingFlow.qml     the card: header (brand, ProgressDots, skip), step Loader, footer
├── OnboardingState.qml    navigation, terminal probe, preset choice, tour, queued installs, exclusive choice
├── OnboardingSteps.js     step registry (id, component, icon, title/subtitle keys, hero)
├── OnboardingModel.js     pure helpers: probe script + parser, TOUR, findKeys, presetLook, OLLAMA_MODELS/pullState
├── FinishModel.js         pure helpers of the summary: install split/counts, display/keyboard lines
├── Step*.qml              one file per step (get `wizard`, the OnboardingState)
├── MonitorUpgradeCard / KeyboardSetupCard   parts of StepDisplays
├── LookPresetGrid / LookWallpaperStrip / OnboardingTabs   parts of StepLook
├── OllamaPullRow          StepAi: "pull a model" chips under Ollama (ExtrasService.ollamaPull)
├── SummaryCard / ExclusiveChoice   parts of StepFinish
├── PresetCard / PresetPreview   static mini desktop from a preset's bar.json/theme.json
├── DryRunBadge / DryRunWallpapers   dry run only (see DRY RUN)
├── FocusChip / ChoiceRow  kit wrappers: a keyboard-reachable Chip, a ListRow that checks / toggles
└── StepScaffold / ProgressDots / SakuraLogo / TourTask
```
State/lifecycle: `modules/services/OnboardingService.qml` (`visible`,
`peek`, `open/close/toggle/complete`, auto-show).

## RULES
- Built only from the UI kit (`qs.modules.components.kit`): text buttons are
  `FocusChip`, rows `ChoiceRow` / `ListRow`, sections `Group`; no raw font sizes,
  durations, hex or Ui.js washes (`tests/onboarding.test.cjs` checks it).
  Renders: `onboarding_render.py --language ink,glass,tiles --palette '#3f8f4f'`.
- Adding a step = `Step<Name>.qml` + one entry in `OnboardingSteps.js` +
  `onboarding.*` translations (en/es/ru). `tests/onboarding.test.cjs` checks
  files and keys.
- Settings are written through `SettingsStore` (live preview); staged
  domains are applied when the wizard finishes or is skipped.
- `general.onboardingDone`: default false; Config.qml marks a general.json
  written before the key existed as done (existing installs never see the
  wizard by itself); finish/skip/Esc set it true. Re-run: Settings > About,
  `<app> run onboarding`, launcher `> onboarding`.
- Keybind tour completion comes from `GlobalShortcuts.commandRan`; while a
  task's panel is open the wizard peeks (`OnboardingService.peek`: window unmapped, `OnboardingPeekPill` shown).
- Peek: `PeekButton` ("Preview on desktop", Look and Terminal steps) sets `peek`; the pill's "Back to setup" clears it.
- Every step `wizard.remember(key, value)`s what the user chose (resume shows it).
- Apps / AI steps are `CatalogHost`s (modules/extras): installs go to the
  backend queue (`ExtrasService.install`), never run from QML, and keep
  running after the wizard closes; queued ids are remembered (`installs`)
  for the summary. Apps preselects the recommended missing apps on the
  first visit only (`apps` remembers the selection).
- Exclusive mode (Hyprland, `ExclusiveService`): the summary toggle only
  remembers `exclusive`; `finish()` on the last step enables it.
- Display changes go through `DisplaysService.apply` (live, 15 s keep/revert prompt);
  OnboardingWindow unmaps while a live change is pending so the prompt is on top.

## DRY RUN
`<app> onboarding --dry-run [--keep]` (`backend/cmd/yozakura/cmds_onboarding_dryrun.go`)
starts `onboarding-dryrun.qml` (repo root: only the wizard, peek pill,
display prompt and `DryRunWallpapers`; it loads nothing until realpath
shows the config/cache/state dirs inside the dry-run dir, and gives up
after 20 s without a wizard) with `<PREFIX>DRYRUN=1` and the XDG dirs on
plain temp copies. `DryRun` (modules/globals) is the switch + journal;
`BackendService` fails closed: only the reads of
`modules/services/DryRunMethods.js` reach the daemon, every other call is
answered by `DryRunBackend.js` (unknown ones journaled as "unmocked call").
A new read the wizard needs goes in that allowlist; a mutating method gets
a journal line there (and fake events in DryRunBackend.js); a QML `Process` /
CLI call that changes the system on the wizard path checks `DryRun.active`
and journals instead (see PresetsService, CompositorTomlWriter, Colors
generators, GlobalShortcuts). `DryRunBadge` marks the card and the pill.

## SEPARATE PROCESS
With `performance.separateWindows` the wizard runs as its own Quickshell
process (`onboarding-window.qml`, `<PREFIX>ROLE=onboarding`, started by the
daemon like Settings, see modules/settings/AGENTS.md SEPARATE PROCESS).
`OnboardingService.visible` in the main shell mirrors the process
(`SeparateWindows`): the first-run auto-show, `<app> run onboarding` and
Settings > About open it there; when it closes (finished, skipped, Esc or
crashed) the main shell marks it dismissed for the session. In the window,
`OnboardingService.open()` resumes from the saved progress, on the screen the
main shell chose. Real changes as in-process: settings through
`SettingsStore` (staged ones preview through the daemon's `preview` relay and
are applied by `finish()`), `general.onboardingDone` written by `complete()`
in the window (the main shell follows general.json), displays through the
daemon (the wizard unmaps while a live change waits; the keep/revert prompt
is the main shell's), installs through the daemon queue, wallpapers through
the main shell (RemoteWallpapers). Keybind tour: `GlobalShortcuts` in the
window listens to the daemon's `ui` stream (commandRan only, never runs a
command, as the dry run), "Try" sends `ui.run` (`tryCommand`), and the main
shell relays whether one of its panels is open (`shellPanelOpen`) and its
bottom bar height (`shell.state`, for the peek pill). The summary's Settings
links finish the wizard first and ask the main shell to open Settings
(`settings.open`). The window quits once the wizard closed and no
exclusive-mode switch is pending (its failure is notified through the
daemon).

## VERIFY
`tests/onboarding.test.cjs`, `tests/onboarding-finish.test.cjs`, `tests/onboarding-ui.test.py`, `tests/onboarding-apps-ui.test.py`, `tests/onboarding-dryrun.test.py`, `tests/dryrun-backend.test.cjs`
(`tests/lib/onboarding_env.py`), renders:
`tools/render/onboarding_render.py [--mode dark|light|both] [--lang ru] --out DIR`.
