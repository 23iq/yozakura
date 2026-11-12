# SETTINGS KNOWLEDGE BASE

## OVERVIEW
The settings window (`SettingsWindowInProcess.qml`, loaded by `shell.qml`, or
its own process with `performance.separateWindows`, see SEPARATE PROCESS) is schema
driven: settings are *declared* in `schema/*.js` and rendered by generic
components. Search, modified/reset state and the audit are all generated from
the same declarations.

## STRUCTURE
```
modules/settings/
├── SettingsWindow.qml      FloatingWindow wrapper without content (placement on the focused workspace,
│                           re-homing, unsaved-changes guard)
├── SettingsWindowInProcess.qml  + SettingsShell, static (shell.qml KeepAliveLoader)
├── SettingsWindowSeparate.qml   + SettingsShell by URL, async, behind SettingsLoading (settings-window.qml)
├── OpeningPill.qml         main shell: "Opening Settings..." while a window process starts
├── ConfigWrite.js          pure: one dotted key into Config (SettingsStore.set, the main shell's PreviewSink)
├── SettingsShell.qml       sidebar + current page + ChangesBar, keyboard shortcuts
├── SettingsPageHost.qml    the page Loader: fresh per category, page table (SettingsPage fills sections per frame)
├── SettingsSidebar.qml     brand, search (schema index), grouped categories (NavItem)
├── SettingsPage.qml        renders one schema category (PageHeader + SettingsSection...)
├── SettingsSection.qml     titled card of SettingRow
├── SettingRow.qml          label/description/modified dot/reset + typed control + preview
├── SettingLabel.qml        a row's label column; DisabledNote.qml: why a row is greyed + [Turn on]
├── DisabledReason.js       pure: the failing condition -> reason text / the one switch that fixes it
├── ViewToggle.qml          sidebar Simple / All switch; SimpleFooter.qml: "N more ... Show all"
├── connect/ConnectPage.qml Network/Bluetooth/Sound/Effects pages: the live device panels
├── mods/                   the Mods page (ModsEditor + parts, ModsModel.js)
├── changes/                the Changes page (ChangesPage, ChangeRow; ChangesModel.js pure)
├── thumbs/                 small card previews for `display: "cards"` selectors
├── Macros.js, Synonyms.js  pure: macro sliders' key mapping; search synonyms (en + ru)
├── AboutPage / PlaceholderPage / PageHeader / PillButton / NavItem / ChangesBar
├── SchemaUtil.js           pure: keys, conditions, validation, search index (node-tested)
├── SettingsDefaults.js     default of any key, from config/defaults/*.js
├── Registry.js             custom editor / preview name -> file
├── BarModules.js, Ui.js    bar module presentation, small UI helpers
├── PanelsModel.js          pure bar.panels edits (add/remove/style/edge/move module)
├── PanelSketch.js          pure schematic geometry of a panel (PanelsSchematic)
├── schema/Categories.js    information architecture: groups + categories
├── schema/<category>.js    one file per migrated category
├── store/SettingsStore.qml get/set/reset/isModified + change flow (singleton)
├── store/SchemePreviews.qml palettes per matugen scheme (`yozakura schemes`)
├── controls/               typed controls (Toggle, Slider, Selector, Number, Text, Font, ColorRole,
│                           List, Path, Screens, Chips) + ChoiceCard, PreviewStage
├── editors/                rich `custom` editors (one file each, `property var entry`)
├── previews/               live previews shown under an entry (`preview`)
├── presets/                the "Presets" page (preset studio): gallery, mixer, editor,
│                           thumbnails (PresetMiniShell, cached PNGs), session banner/pill/toast;
│                           PresetModel.js holds the pure helpers (node-tested)
└── store/PresetStudio.qml  studio data + actions: every operation is `<app> preset ...`
                            (backend/pkg/presets), trial/edit sessions live in the backend
```

## LOOK
The window is built from the shared kit (`qs.modules.components.kit`, see
`docs/superpowers/plans/screens-brief.md`): sidebar rows are `ListRow`s in
labelled blocks (`SectionLabel`, `Categories.sidebarSections()`), search is
the kit `SearchField`, `PageHeader` is title + secondary with a quiet
"Reset page" action, a section is a `Group` (its label action reads Reset /
Show / Hide), a row is body label + caption description with the control
flush right. Controls: `Switch` (ToggleControl), segmented `Chip`s or a
`Dropdown` past `chipLimit` options (SelectorControl), `LineSlider`
(SliderControl), `IconButton` stepper (NumberControl), `FieldBox` behind
text / path / font fields, `ChoiceCard` / `PillButton` on the kit looks.
No raw sizes, paddings or colors in new settings code: Type / Space / Look.
Render: `tools/render/settings_render.py --languages ink,glass,tiles PAGE...`.

Hand-written pages (`page` in Categories.js) are mapped by name in
`SettingsPageHost.pages`. The preset studio never writes preset files itself;
a new mixable aspect is one entry in `backend/pkg/presets/aspects.go` (+
`tests/fixtures/preset-aspects.json`, icon in `PresetModel.ASPECT_ICONS`,
`prefs.presets.aspect.<id>[.desc]` strings). Render it with
`tools/render/presets_render.py`.

## ADDING A SETTING
1. Make sure the key exists in `config/defaults/<domain>.js` (run `make
   schema`: it regenerates the typed adapter `config/adapters/<Domain>Adapter.qml`)
   and, for staged domains, the GlobalStates snapshot list - the audit fails
   otherwise.
2. Add one entry to the category's `schema/<category>.js` section:
   ```js
   { "key": "bar.frameThickness", "type": "slider", "min": 0, "max": 40, "step": 1, "unit": "px",
     "visibleWhen": { "key": "bar.frameEnabled", "equals": true },
     "label": "prefs.bar.frame_thickness", "description": "prefs.bar.frame_thickness.desc",
     "keywords": "frame thickness width border" }
   ```
3. Add the label/description keys to `translations/{en,es,ru}.json`.
4. `make schema`: the entry (label, description, options, range,
   `visibleWhen`) becomes part of the settings catalog
   (`assets/schema/*.schema.json`) used by `yozakura config` and the MCP
   tools. Allowed values of `custom` entries (the editor owns them) go in
   `config/meta/<domain>.js`.

Entry fields: `key` (dotted, `domain.prop[.sub]`; `wallpaper.*` keys live in
~/.cache/yozakura/wallpapers.json), `type` (`toggle | selector | slider | number
| text | font | color-role | list | path | screens | multiselect | macro | custom`;
`macro` = one slider over several keys, `"macro": "<id>"` from `Macros.js`, see MACROS;
`color-role` = palette swatches + alpha for a color spec, with `gradient:
true` a list of up to 4 stops), `label`, `description`, `keywords`,
`placeholder` (i18n key), `pattern` (regex a `text` value must match before
it is saved), `options`
(`[{value, label, icon}]`), `min/max/step/unit`, `specialValues`
(`[{value, label}]`), `visibleWhen` / `enabledWhen` (declarative:
`{key, equals|notEquals|in|truthy|empty}`, `{key, some: {field, in|notIn}}`
(a list holds an item whose field is / is not one of the values; a missing field
counts as not in), `{all|any: [...]}`, `{not: ...}`),
`display: "cards"` + `thumb` (a selector shown as preview cards,
controls/CardSelector; the thumb is a `thumbs/<Name>.qml` registered in
`Registry.THUMBS`, with `property var entry` and `property var value`; use it
only where the choice is visual),
`preview` (Registry name), `component` (custom editor name), `keys` (every
key a composite entry reads/resets), `sizeKey` (font), `resettable: false`,
`compositor` (entry or section shown only on that compositor, e.g. `"hyprland"`),
`id` (when there is no single `key`), `target` (PageLink), `sizeUnit`
(font), `advanced` (expert knob: raw px / ms, "Match shell ..." plumbing,
endpoints, per-surface opacities; shown only in the All view, see below),
`reason` (i18n key: why the row is greyed when `enabledWhen` is not one
switch; a single-toggle condition is named automatically with a [Turn on]
action, tests/settings-advanced.test.cjs enforces it), `invert` (a toggle
shown on for `false`: a positive name for a double-negative key such as
notch.disableHoverExpansion "Media panel"; the key never changes),
`surface` (a host/style picker's `modules/shell/hosts/SurfaceRegistry.js`
id: the row notes "Island is off - shown as X" while the notch is off).

Collection types (controls/ListControl, PathControl, ScreensControl,
ChipsControl; pure helpers in SchemaUtil: listInsert/Remove/Move/Set,
newListItem, toggleValue):
- `list`: an array. Objects: `fields: [{key, type: text|number|selector|path|toggle,
  label, placeholder, min/max/step/unit, options, monospace, secret (masked text), pattern, flex
  (share of the row, e.g. 0.5)}]`, `newItem`, `itemLabel` ("Rule %1"),
  `addLabel`, `emptyLabel`; strings: `itemType: "text" | "path"` (+ `pathKind`).
  Items can be added, removed and reordered (system.idle.listeners,
  notifications.rules, system.disks).
- `path`: text + Browse (zenity/kdialog), `pathKind` "file" | "dir", `filter`.
- `screens`: monitor multi-select (`[]` = every screen), lists connected and
  remembered names.
- `multiselect`: chips over `options`, value = array of option values.

A rich editor: add `editors/<Name>.qml` (root has `property var entry`,
reads/writes through `SettingsStore`), register it in `Registry.js`, use
`"type": "custom", "component": "<Name>"`. Previews likewise in `previews/`.

Section fields: `id`, `title`, `entries`, and `collapsible: true` (+
`collapsed: true` to start folded) for advanced options; a search jump into
a folded section unfolds it. A category file may pull sections from a
sibling file (appearance.js splices in `schema/glass.js`).

## SIMPLE / ALL
`general.settingsShowAll` (machine-local, the sidebar ViewToggle; default
Simple). Simple hides `advanced` entries and sections left empty, keeps an
advanced entry the user changed, and ends the page with SimpleFooter. All
shows every entry in place. Search indexes everything; a jump to an
advanced entry reveals it in Simple (`SettingsStore.revealed`, cleared on
page change). A new feature is ONE obvious row in Simple (on/off or style),
its fine options `advanced`. Helpers: `schema/Advanced.js`.

## MACROS
Look > "Quick tune" (`schema/macros.js`): Motion, Density, Roundness, Depth,
Glass. `Macros.js` (pure, tests/settings-macros.test.cjs) lists each macro's
keys and points; a point leaving a key out does not care about it. The
slider shows the point every key matches, else "Custom" with the handle on
the nearest point. Moving it writes ONLY the keys that differ through
`SettingsStore.set` (staged, Discard undoes it); nothing is written until the
user moves it. Defaults must sit on a point. Compositor-only keys carry
`compositor: [...]` and are skipped elsewhere.

## SEARCH SYNONYMS / CHANGES PAGE
`Synonyms.js` (tests/settings-synonyms.test.cjs): words people type (en + ru)
-> the words the schema uses; `SchemaUtil.search` also scores each
substituted query, a little below direct hits. Add a row when a common word
finds nothing. The "Changes" page (`changes/`, pure `ChangesModel.js`,
tests/settings-changes.test.cjs) lists every entry `isModified` by page with
reset + open; while a preset is applied it can list the differences from the
preset instead (backend `preset.status` via PresetStatusService; reflects
applied config, not staged edits).

## ADDING A CATEGORY
Create `schema/<id>.js` exporting `category = {id, icon, title, description,
keywords, sections: [{id, title, entries: [...]}]}`, import it in
`Categories.js` and put it in the group of the element it controls (one
page per element; a setting is declared on one page only, see
tests/settings-pages.test.cjs). Expert knobs get `"advanced": true`. A page
merged into another keeps its old id working through `MOVED` in
Categories.js; renamed keys keep the user's value through
`config/meta/KeyAliases.js`.

## CHANGE FLOW
`SettingsStore.set()` writes Config immediately (the whole shell previews the
change live). For staged domains it first calls the GlobalStates
`mark{Theme,Shell,Compositor}Changed()` (snapshot + pause auto-save, the same
flow the old panels used); the ChangesBar then applies (`apply*Changes`,
writes the JSON files) or discards (restores the snapshot). Domains without a
snapshot list are saved immediately (`Config.save<Domain>()`), and
`wallpaper.*` keys go straight to the wallpaper manager (wallpapers.json).

## SEPARATE PROCESS
`performance.separateWindows` (default off): Settings (and the setup wizard,
see modules/onboarding/AGENTS.md) runs as its own Quickshell process that
costs nothing until opened and gives all its memory back when closed; each
open compiles the window again (a few seconds, where a kept-alive in-process
window reopens at once). Off, everything is as before.
- Launch: every open path still sets `GlobalStates.settingsWindowVisible` /
  `settingsCategory`; the main shell's `SeparateWindows` (modules/services)
  turns that into `windows.open {kind, page, screen, workspace}` /
  `windows.close` and mirrors the process in the flag (true while it runs).
  The daemon (`backend/pkg/svc/windows`) starts `qs -p <shell dir>/settings-window.qml`
  next to the running shell.qml (mods generation or Nix store path; base
  source as fallback) with `<PREFIX>ROLE=settings` and `<PREFIX>WINDOW_*`,
  one per kind: a later open sends `windows.command` raise (new page,
  placement again), a toggle sends close (the window asks about unsaved
  changes); a raise asked while the window still starts is kept (the
  last one) and handed over in the answer to its `windows.ready`, a close
  then stops the process (it never maps; an open after it starts a new one). Closed,
  the window reports `windows.hiding` and quits (1 s grace for the last
  writes); an open meanwhile raises it again (a new process if it quit
  first),
  the daemon reaps it, kills it on shutdown / reload / quit (SIGTERM, then
  SIGKILL of its group), never restarts it; the orphan sweep knows the entry
  files. A start failure falls back to the in-process window (so does no
  daemon connection, `qs -p shell.qml` alone, no answer within 3 s, or a
  process that exits before its window showed, unless the daemon stopped
  it at shutdown / reload or its connection is gone; the wizard then does
  not count as dismissed). A process that exited before it showed is not
  started again: that window opens in-process for the rest of the session
  (until the setting is turned off), logged once; a window open
  in-process stays so when the setting changes. `OpeningPill` shows until
  the window reports `windows.ready`; the frame maps first
  (`SettingsWindowSeparate`: background + "Loading settings...", content by URL).
- Role: `ProcessRole` (modules/globals) keeps every session-wide service to
  the main shell (see modules/services/AGENTS.md); a notification raised in
  the window goes to the daemon (`notify.send`). The role variable is
  trusted only in a window entry file (its `ShellId` pragma): `shell.qml` is
  always the main shell. The daemon drops `<PREFIX>ROLE` / `WINDOW_*` from
  its own environment and every other child (`envclean.WindowVars`), and a
  window starts detached programs through `ProcessRole.detached(argv)`
  (xdg-open, terminals), which removes them.
- Staged changes (one staging, as in-process): the window stages in its own
  Config exactly as in-process (`SettingsStore.set` -> GlobalStates snapshot,
  auto-save paused) and, for a staged domain only, relays `preview.set
  {owner, key, value}` (backend/pkg/svc/preview). Every other process (the
  main shell, the other window) applies it in `PreviewSink` with the same
  `ConfigWrite.assign` + snapshot (`GlobalStates.mark*Changed`), so the
  desktop previews it, the other window shows it as unsaved, and nothing of
  it is written. In-process Settings and the wizard share one set of
  snapshots, so here too it is one staging: Apply or Discard by either ends
  all of it (`preview.discard` restores every process's snapshots).
  Apply (`PreviewSink.applyOwn`): the window drops its snapshots and sends
  `preview.commit`; the main shell applies the staged entries the commit
  carries (a `preview.set` the stream dropped), runs the same
  `apply*Changes` as in-process and answers `preview.written`. Its Config holds every staged
  value plus what the desktop changed meanwhile in a staged domain (widget
  positions, dashboard cells, live activities), so those are written too,
  as with one in-process Config; the windows follow the files. Only when no
  main shell answers (2 s in the daemon, 4 s without the daemon) does the
  window write, and only the domains it changed, each as only its own
  changes over the current file (`StagedDomains.js`,
  `ConfigFile.writeMerged`); it does not quit while that answer is pending. A window process gone (crash,
  kill, closed without applying) while the other window runs leaves the
  staging to that one; the last one gone discards it. The daemon keeps the
  staged values, so a process (re)started meanwhile gets them again.
  Unstaged settings are written by the window at once; the main shell
  follows the file, and every process follows `config set`, MCP and presets
  through its file watchers. Two processes auto-saving one domain do not
  lose each other's edits: an edit still waiting for its write when the file
  changes is merged into the new contents (`config/ConfigMerge.js`).
- What the window cannot own is asked of the main shell
  (`windows.relay {to: "shell", topic}`): wallpaper changes
  (`RemoteWallpapers`, which reads wallpapers.json and scans the library like
  the real manager), "Regenerate now" of app themes, desktop-widget edit mode
  (the state and the depth clock areas come back), opening the wizard.
- Pages: config-backed pages and search work on the window's own Config; Displays,
  Keyboard, Extras, Mods, Presets, Routines, AI usage are daemon-backed (the
  keep/revert prompt is drawn by the main shell from the daemon's session);
  Network / Bluetooth / Sound talk to the system directly; the keybind editor
  writes binds.json and the main shell's TOML writer follows the file; AI
  providers / agents / MCP use a second `Ai` instance (reads only; automations
  run in the main shell); About shows the last update check (scheduled checks
  run in the main shell, "Check now" runs in the window). Not out of process:
  the depth-clock matte progress (DepthMatteStatus) only sees jobs of its own
  process, so it does not show the main shell's matte build.

## VERIFY
- `make check`: `settings-schema` audit (keys/defaults, translations,
  options/ranges, conditions, registry, snapshot lists),
  `tests/settings-schema.test.cjs` (schema/search/layout helpers),
  `tests/settings-ui.test.py` (renderer behaviour, offscreen).
- Separate process: `tests/separate-windows.test.py` (main-shell side: open/close
  mirror, fallback, preview set/discard/commit, relays), `tests/window-entries.test.py`
  (root files), `tests/process-role.test.py`, `tests/remote-wallpapers.test.py`,
  `tests/config-write.test.cjs`, Go `backend/pkg/svc/{windows,preview}`.
- `tools/render/settings_render.py [--mode dark|light|both] [--scroll N]
  [--search q] [--size WxH] CATEGORY...` renders pages to PNG in a private
  Xvfb with your real config, palette and wallpapers.
