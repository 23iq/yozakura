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
└── ChoiceRow / NavButton / SectionLabel / StepScaffold / ProgressDots / SakuraLogo / TourTask
```
State/lifecycle: `modules/services/OnboardingService.qml` (`visible`,
`peek`, `open/close/toggle/complete`, auto-show).

## RULES
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

## VERIFY
`tests/onboarding.test.cjs`, `tests/onboarding-finish.test.cjs`, `tests/onboarding-ui.test.py`, `tests/onboarding-apps-ui.test.py`
(`tests/lib/onboarding_env.py`), renders:
`tools/render/onboarding_render.py [--mode dark|light|both] [--lang ru] --out DIR`.
