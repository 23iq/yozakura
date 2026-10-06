# AGENTS.md: modules/widgets/launcher/

## OVERVIEW
The launcher (notch module "launcher"). Tab 0 is a provider-based search:
apps, calculator/units/currency, shell commands, wallpapers, files, ask AI,
merged in the order configured in `prefix.launcher.order`. Tabs 1-4 are the
prefix tabs (clipboard, emoji, tmux, notes) from the dashboard, loaded on
demand. Keyboard first: Enter runs, Shift+Enter / right click shows options,
Tab completes a command or asks the AI, Esc closes.

## STRUCTURE
```
launcher/
├── LauncherView.qml      root: search tab + prefix tabs (StackLayout/Loaders), tab prefix detection
├── LauncherSearch.qml    search field, selection/expansion, keyboard handling
├── LauncherResults.qml   creates the providers (by URL from Providers.js), routes the query, merges results
├── ResultList.qml        ListView: rows, sliding highlight, expanded options
├── ResultRow.qml         one result (icon/thumbnail/glyph, title, subtitle, badge, Enter hint)
├── ResultOptions.qml     options of an expanded result
├── KeyHint.qml           "Launch ⏎" hint with a keycap
├── Providers.js          provider registry + routing (pure, tests/launcher.test.cjs)
├── Calc.js / Units.js    safe calculator, unit + currency conversion (pure)
├── Commands.js           "> command" matching / args / run plan over assets/commands/commands.json (pure)
├── FileQuery.js          fd / plocate command line + output parsing (pure)
└── providers/
    ├── LauncherProvider.qml   base: search(), compute(), activate(), options(), completion()
    ├── AppsProvider.qml       AppSearch; options launch / pin / desktop shortcut
    ├── CalculatorProvider.qml + CurrencyRates.qml (open.er-api.com, cached, offline table in assets/launcher)
    ├── CommandsProvider.qml   registry shared with `<app> cmd` and the MCP shell_command tool
    ├── WallpapersProvider.qml wallpapers by name, thumbnails, random
    ├── FilesProvider.qml      $HOME through fd/plocate, debounced; open / reveal / copy path
    └── AiProvider.qml         sends the query to Ai.askQuick (notch quick ask)
```

## ADDING A PROVIDER
1. `providers/<Name>Provider.qml` extending `LauncherProvider` (override
   `compute(text, mode)` for synchronous results, or `search()` for async
   ones; `activate()` returns true to close the launcher).
2. One entry in `Providers.js` (`id`, `file`, `icon`, `prefix` key,
   `mixed`/`empty`), its id in `config/defaults/prefix.js` `launcher.order`
   (and a prefix key + `Config.qml` property if it has one).
3. Translations `launcher.provider.<id>` and `.desc` (settings editor).
4. `make schema`; tests in `tests/launcher.test.cjs` / `tests/launcher-ui.test.py`.

A quick command is one entry in `assets/commands/commands.json` (no QML):
it shows in the launcher (`> id`), `<app> cmd id` and the MCP tools.

## CONFIG
`Config.prefix.*`: tab prefixes (cc/ee/tt/nn), provider prefixes
(`calculator` "=", `commands` ">", `routines` "@", `files` "ff", `ai` "?", `wallpapers` "ww")
and `prefix.launcher` (order, disabled, aiOnTab, filesInMixed, fileBackend,
fileMaxResults, fileExcludes, currencyRefreshHours). Settings: category
"launcher" (`modules/settings/schema/launcher.js`, editor
`LauncherProvidersEditor`). Word prefixes need a space ("ff notes"), symbol
prefixes do not ("?why").

## VERIFY
`tests/launcher.test.cjs`, `tests/launcher-ui.test.py` (offscreen, stubs in
`tests/lib/launcher_env.py`), renders: `tools/render/launcher_render.py`.

## ANTI-PATTERNS
- Running an app without `UsageTracker.recordUsage()` (AppsProvider does it).
- Opening another notch module from `activate()` synchronously: the launcher
  closes after it; defer with `Qt.callLater` (AiProvider, CommandsProvider).
- Missing `prefixDisabled` after Backspace leaves a tab: re-detection loops.
