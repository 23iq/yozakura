# AGENTS.md: modules/onboarding/

## OVERVIEW
First-run setup wizard: a full-screen glass card (Overlay layer, namespace
`<app>:onboarding`) walking through look, wallpapers, terminal/language,
AI agents + voice, an interactive keybind tour and a summary.

## STRUCTURE
```
onboarding/
├── OnboardingWindow.qml   PanelWindow on the screen it opened on (shell.qml Loader)
├── OnboardingFlow.qml     the card: header (brand, ProgressDots, skip), step Loader, footer
├── OnboardingState.qml    navigation, detection probe, preset choice, tour, voice setup job
├── OnboardingSteps.js     step registry (id, component, icon, title/subtitle keys, hero)
├── OnboardingModel.js     pure helpers: probe script + parser, TOUR, findKeys, presetLook, voiceProgress
├── Step*.qml              one file per step (get `wizard`, the OnboardingState)
├── PresetCard / PresetPreview   static mini desktop from a preset's bar.json/theme.json
└── ChoiceRow / NavButton / SectionLabel / StepScaffold / ProgressDots / SakuraLogo / TourTask
```
State/lifecycle: `modules/services/OnboardingService.qml` (`visible`,
`suspended`, `open/close/toggle/complete`, auto-show).

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
  task's panel is open the window unmaps (`OnboardingService.suspended`).

## VERIFY
`tests/onboarding.test.cjs`, `tests/onboarding-ui.test.py`
(`tests/lib/onboarding_env.py`), renders:
`tools/render/onboarding_render.py [--mode dark|light|both] [--lang ru] --out DIR`.
