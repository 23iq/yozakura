# SETTINGS KNOWLEDGE BASE

## OVERVIEW
The settings window (`SettingsWindowInProcess.qml`, loaded by `shell.qml`, or
its own process with `performance.separateWindows`, see SEPARATE PROCESS) is
the shell's showpiece and is schema driven: settings are *declared* in
`schema/*.js` and rendered by generic components. Every change applies at
once and can be undone; there is no Apply step. A page starts with its
**stage** (a live miniature of the shell element it controls), then a few
short rows. Search, modified / reset state, the CLI / MCP catalog and the
audits are all generated from the same declarations.

Design rules (owner's brief, binding for every page):
- Only the important options are rows of the window. Rare knobs stay in the
  schema with `advanced: true` (reachable through `yozakura config`, MCP and
  presets, never rendered, never found by the window's search).
- No text walls: a row is a short sentence-case label (four words at most)
  and its control. The description is the label's tooltip, never printed.
  A one-line `hint` (eight words at most) only where the effect cannot be
  seen on the stage.
- Visual by default: the stage reacts to every row; a choice between looks
  is a row of picture cards.
- One control per setting, one name per concept (the Island, not the notch).

## STRUCTURE
```
modules/settings/
├── SettingsWindow.qml      FloatingWindow wrapper (placement on the focused workspace, re-homing)
├── SettingsWindowInProcess.qml  + SettingsShell, static (shell.qml KeepAliveLoader)
├── SettingsWindowSeparate.qml   + SettingsShell by URL, async, behind SettingsLoading (settings-window.qml)
├── OpeningPill.qml         main shell: "Opening Settings..." while a window process starts
├── SettingsShell.qml       sidebar + DestinationHeader + SettingsPageHost + UndoPill; shortcuts
├── SettingsSidebar.qml     brand, search (window rows only), flat destination list (NavItem),
│                           one sliding selection mark (accent tint + brush signature)
├── DestinationHeader.qml   destination icon + title, its tabs (kit Segmented), Reset page
├── SettingsPageHost.qml    creates pages by URL on first visit, keeps the last 4 (PageCache.js)
├── SettingsPage.qml        a schema category: its stage (Loader by URL) + SettingsSection...
├── SettingsSection.qml     a kit Group of SettingRows (window entries only); hidden with no row
├── SettingRow.qml          label (+ Tooltip, reset, caption) and the typed control; points the stage
├── UndoPill.qml            "<what> changed · Undo" after every change (Redo after an undo)
├── PageHeader.qml          a hand-written page's action row (the window draws the title)
├── UndoModel.js            pure: undo steps, coalescing, labels (tests/settings-undo.test.cjs)
├── PageCache.js            pure: which pages stay alive (same test)
├── ConfigWrite.js          pure: one dotted key into Config (SettingsStore, PreviewSink)
├── SchemaUtil.js           pure: keys, conditions, inWindow, validation, search index (node-tested)
├── ResetModel.js           pure: which entries Reset page and the counters touch
├── DisabledReason.js       pure: the failing condition -> reason text / the one switch that fixes it
├── Registry.js             names -> files: EDITORS, PREVIEWS, THUMBS, STAGES, PAGES
├── stages/                 Stage.qml (frame), ScreenMini.qml (the whole screen, in layers),
│                           StageSpot.qml (highlight), <Page>Stage.qml
├── thumbs/                 picture-card thumbs (MiniScreen.qml: the wallpaper screen they draw on)
├── controls/               typed controls (Toggle, Slider, Selector, Number, Text, Font, ColorRole,
│                           List, Path, Screens, Chips, Macro) + ChoiceCard, CardSelector
├── editors/                rich `custom` editors (one file each, `property var entry`)
├── previews/               old under-row previews (`preview`), for pages not converted yet
├── schema/Categories.js    information architecture: destinations, tabs, sidebar blocks, resolve()
├── schema/<category>.js    one file per category (a tab of a destination)
├── store/SettingsStore.qml get / set (live + undo) / stageSet (wizard) / reset / focusKeys
├── store/PresetStudio.qml  preset studio data + actions (`<app> preset ...`)
├── presets/, displays/, keyboard/, extras/, connect/, mods/, changes/, system/  hand-written pages
└── Macros.js, Synonyms.js  pure: macro sliders' key mapping; search synonyms (en + ru)
```

## LOOK
Built only from the kit (`qs.modules.components.kit`); no raw sizes, colors
or Rectangles/Texts (`kit-literals` ratchet: a new directory must be at
zero; draw shapes of a miniature with `Mark`, surfaces with `StyledRect` and
the theme's variants). The window must look deliberate in every visual
language (ink, glass, tiles, classic, device) and in dark and light; nothing
branches on the language name (`Look`).
- Sidebar: brand, boxed SearchField, `SectionLabel` blocks, `NavItem` rows
  (Space.controlS high, icon + label); the selection is ONE `StyledRect`
  "primary" tint with the brush signature that glides (Motion.glide).
- Header: destination icon (accent) + title role; tabs are the kit
  `Segmented` (`focusable`, Left / Right); a tab to the right slides the page
  in from the right (`SettingsPageHost.direction`).
- Rows: label `body`, control flush right (inline) or full width under the
  label (cards, editors, lists); hover / focus = the language's hover box;
  a search jump = accent wash + focus.
- Picture cards: `ChoiceCard` - the picture is the card (rounded mask, a
  hairline edge, lifts on hover); selected = accent ring + title in the
  active weight + check; FocusRing on keyboard focus.
- Stage: `Stage` = wallpaper (palette backdrop without one) in a rounded,
  hair-lined frame, Look.radius("surface"); the miniature on top.
- Undo pill: popup surface, springs in, stays 5 s (longer while hovered).
Render: `tools/render/settings_render.py --wallpaper assets/wallpapers_example/wallpaper-03.png
--languages ink,glass,tiles,classic,device [--mode light] [--size 1180x2400] PAGE...`
(`--hover ENTRY` lights a stage part, `--undo` shows the pill).

## NAVIGATION
`schema/Categories.js`: `groups` are the destinations of the flat sidebar
(Bar, Island, Dock, Launcher, Dashboard, Notifications, Lock screen, Desktop /
Look, Wallpaper, Presets / Assistant / Displays, Keyboard & input, Windows,
Network, Sound, Power, Apps, System), each `{id, icon, title: prefs.dest.<id>,
categories: [tab ids]}`; `SIDEBAR_SECTIONS` the four labelled blocks. A
category is one tab: its `title` is the tab label (one to three words). One
tab = no tab strip. `resolve(id)` accepts a category id, a `MOVED` id
(merged pages, former sidebar groups such as `popups`) or a destination id
(its first tab), so `<app> run settings <id>`, `GlobalStates.settingsCategory`
and old deep links keep working. `tabsOf(categoryId)`, `groupOf(categoryId)`.
A category is either schema driven (`sections`, rendered by SettingsPage) or
a hand-written page (`page`: a `Registry.PAGES` name, loaded by URL).

## CHANGE FLOW
- `SettingsStore.set(key, value)`: LIVE. Config is written at once (the whole
  shell follows), the domain's own auto-save persists it (`ConfigFile`,
  coalesced: a burst is one write 150 ms after it stops, and a long burst
  such as a slider drag is written every 250 ms, `config/WriteThrottle.js`),
  `wallpaper.*` keys go to the wallpaper manager. The change is recorded on
  the session undo history (`undoStack` / `redoStack`, `UndoModel.js`): the
  same setting changed again within 1.5 s merges into one step, a step that
  ends where it began disappears. `undo()` / `redo()` (Ctrl+Z, Ctrl+Shift+Z /
  Ctrl+Y, the pill) replay the values without recording. `lastStep` feeds
  the pill. A key with no entry of its own is named by its parent entry.
- `SettingsStore.transaction(label, fn)`: every change `fn` makes is ONE step
  (Reset page, a reset of a multi-key entry, a macro slider, an editor that
  rewrites a whole object). Use it in any editor that writes several keys.
- `reset(entry)`, `resetCategory(category)` (Reset page, window rows only,
  `ResetModel.activeItems`): one step each; no confirmation (undo instead).
- `SettingsStore.stageSet(key, value)`: the setup wizard only
  (`OnboardingState.set`). Staged like the old Apply flow: the GlobalStates
  snapshot of the domain is taken and its auto-save paused; `apply()` writes
  (the wizard's finish), `discard()` restores. A wizard in its own process
  relays staged values to the main shell (`preview.set`, PreviewSink.qml).
  While the wizard holds a domain, a live `set` of that domain writes the
  file explicitly (the wizard's staged values of that domain go with it).
- `SettingsStore.flush()`: writes every coalesced edit still waiting (preset
  commands call it through `PresetStudio.afterFlush`).
- Nothing else may call `GlobalStates.mark*Changed` from the window: an
  editor that wrote around SettingsStore staged changes nobody applied
  (BarActivitiesSettings takes a `write` function now).

## SEPARATE PROCESS
`performance.separateWindows` (default off): Settings (and the setup wizard,
see modules/onboarding/AGENTS.md) runs as its own Quickshell process that
costs nothing until opened and gives all its memory back when closed.
- Launch / close / raise / fallback: unchanged (`SeparateWindows`,
  `backend/pkg/svc/windows`, `windows.open/command/ready/hiding`, OpeningPill;
  a start failure falls back to the in-process window). Closing never asks
  anything: every change is already saved. The process quits 1 s after it
  hid, after the last coalesced writes (ConfigFile flushes a pending write
  on destruction).
- Live changes: the window writes its own Config and its files (the same
  coalesced auto-save as in-process); the main shell follows the files
  through its file watchers. Why this and not the preview relay: the relay
  stages in the main shell (snapshot + paused auto-save) and would need a
  commit protocol to end; plain writes need no protocol, cannot leave the
  main shell holding unsaved state, and the 250 ms cap keeps a slider drag
  visibly live on the desktop (about four reloads per second). Two processes
  writing one domain merge (`config/ConfigMerge.js`).
- Undo in the window is the window's own history; it writes like any change.
- The wizard's staging still uses the relay (PreviewSink: set / discard /
  commit, main shell writes, window fallback after 2 / 4 s) exactly as before.
- Role: `ProcessRole` keeps session-wide services to the main shell; what the
  window cannot own is asked of the main shell (`windows.relay {to: "shell",
  topic}`: wallpaper changes through RemoteWallpapers, "Regenerate now",
  desktop-widget edit mode, opening the wizard).
- Pages: config-backed pages and search use the window's Config; Displays,
  Keyboard, Extras, Mods, Presets, Routines, AI usage are daemon-backed (the
  keep / revert prompt of displays and keyboard is drawn by the main shell);
  Network / Bluetooth / Sound talk to the system directly.

## PERFORMANCE
- Opening the window compiles the shell and ONE page: pages and stages are
  created by URL (`Registry.PAGES`, `Registry.STAGES`); the host imports the
  page directories only so Quickshell's scanner reaches them. Never name a
  page or stage type statically in the shell.
- The last 4 visited pages stay alive, hidden and disabled (PageCache.js);
  a revisit shows the same page at once. Rows of a hidden page point at
  nothing. Keep stages cheap while hidden (no endless animations; a stage
  that animates should gate on `visible`).
- SettingsPage builds its sections a few per frame and stays hidden until
  what is on screen is built (`enterReady`); no row object exists for an
  out-of-window entry.
- Heavy live previews become pictures: the lock screen gallery builds one
  LockView at a time, captures it (`grabToImage`) and destroys it.
- Measure with the audit harness (scratch scripts based on
  `tests/lib/settings_env.py`: time from `select()` to the host's `pageReady`
  and to `item.complete`).

## ADDING A SETTING
1. The key exists in `config/defaults/<domain>.js` (`make schema` regenerates
   the typed adapter); a staged domain also lists it in the GlobalStates
   snapshot list (the wizard uses it).
2. One entry in the category's `schema/<category>.js` section:
   ```js
   { "key": "bar.compact", "type": "toggle",
     "label": "prefs.bar.compact", "description": "prefs.bar.compact.desc",
     "keywords": "compact dense slim thin small height" }
   ```
   Not important enough for the window? Add `"advanced": true` (it stays in
   the catalog and the CLI). Most new knobs are.
3. Label / description keys in `translations/{en,es,ru}.json`.
4. `make schema` (catalog `assets/schema/*.schema.json`).

Entry fields: `key` (dotted, `domain.prop[.sub]`), `type` (`toggle | selector
| slider | number | text | font | color-role | list | path | screens |
multiselect | macro | custom`), `label`, `description` (tooltip + catalog),
`hint` (i18n key: the one visible caption line, rare), `keywords`,
`advanced` (not in the window), `placeholder`, `pattern`, `options`
(`[{value, label, icon}]`), `display: "cards"` + `thumb` (picture cards),
`min/max/step/unit`, `specialValues`, `visibleWhen` / `enabledWhen`
(declarative: `{key, equals|notEquals|in|truthy|empty}`, `{key, some: {field,
in|notIn}}`, `{all|any: [...]}`, `{not: ...}`), `reason` (why an
`enabledWhen` row waits when no single switch decides it), `preview` (old
under-row preview, unconverted pages only), `component` (custom editor),
`keys` (every key a composite entry reads / resets), `sizeKey` / `sizeUnit`
(font), `resettable: false`, `compositor`, `id`, `target` (PageLink),
`invert` (a toggle shown on for false), `surface` (a host picker's surface
id: the row notes "Island is off - shown as X" and HostThumb pictures it).
Section fields: `id`, `title`, `entries`, `advanced: true` (the whole section
is out of the window), `compositor`. A section shows only while one of its
rows does. Category fields: `id`, `icon`, `title` (the tab label),
`description`, `keywords`, `sections`, `stage` (Registry.STAGES name) or
`page` (Registry.PAGES name).

Control mapping (applied everywhere): on / off -> `toggle` (Switch);
2 to 5 visual options -> `selector` + `display: "cards"` + `thumb`;
2 to 4 non-visual options -> `selector` (kit Segmented); more -> `selector`
(kit Dropdown); continuous -> `slider` in human units; a small count ->
`number` (stepper); a font -> `font` (the picker; `sizeKey` adds the size).

## CONVERTING A PAGE (checklist for the remaining destinations)
Reference pages: Bar (`schema/bar.js`, `layout.js`, `stages/BarStage.qml`,
`stages/OpensStage.qml`) and Look (`schema/appearance.js`, `icons-type.js`,
`stages/LookStage.qml`, `stages/TypeStage.qml`).
1. Budget: the page fits in about two window heights (1180x780) and has
   about 8 to 15 rows (the window ~150 in all). Count with
   `tests/settings-window.test.cjs` (add the page to its budget test).
2. Curate: for every entry ask "would most people change this here?". If
   not, `"advanced": true` (or the whole section). Plumbing never stays:
   raw shell commands, timeouts in seconds, mount points, endpoints,
   performance toggles, per-surface opacities, "match the shell" switches.
   A row that only refines another (sub-options of an effect) goes too.
3. One control per setting: if two rows (or two editors) write the same
   key, keep one. A macro covers its keys: the raw knobs go out.
4. Labels: sentence case, four words at most, no internal ids, tool names,
   units in the label or "Enable X" (a switch says that). One name per
   concept (Island; Lock screen; Assistant). Descriptions stay (tooltip and
   catalog) but are one or two plain sentences; never narrate a picture.
5. Visual choices become picture cards: `display: "cards"` + a `thumb`
   (thumbs/<Name>.qml with `property var entry`, `property var value`; draw
   on `MiniScreen` with `Mark` / `StyledRect` / `KitText`, the real shell
   component where it is self-contained, e.g. the bar clock face; register
   it in `Registry.THUMBS`). Options of a registry (styles, numerals) ->
   a small editor that feeds `CardSelector` (editors/IndicatorCards.qml).
6. The stage: anything that sits somewhere on the screen (Island, Dock,
   Notifications, OSD, Desktop widgets, Lock screen, menus, overview) is
   shown in its real position on the screen miniature, never described:
   put a `ScreenMini` in the stage (it already draws every bar panel, the
   island, the dock, the frame, rounded corners and the space they reserve,
   to one scale, from the live config) and draw the page's element in its
   `overlay` with its geometry (`freeRect`, `islandRect`, `edgeDepth(edge)`,
   `unit`); turn layers off that only distract (`showWindows`, `showDock`,
   `showIsland`). `selectable` + `selectedPanel` / `panelPicked(i)` make
   the panels clickable (BarStage: SettingsStore.selectedPanel is shared
   with the bars editor). OpensStage shows the pattern for surfaces: ghost
   outlines with an icon for every place, the hovered / just-changed one
   solid and named, places that coincide share one ghost (no label is ever
   drawn over another). The stage file is `stages/<Page>Stage.qml` with a
   `Stage` root
   (`stageHeight`), registered in `Registry.STAGES`, named by the category's
   `"stage"`. Draw the real thing: the theme's own surfaces (`StyledRect`
   variants "barbg", "popup", "bg"), kit components (they follow the look
   live), real self-contained shell parts loaded by URL (no `import
   qs.modules.<feature>` from settings: the `layers` audit). Read values with
   `SettingsStore.get` so the stage follows every change; animate changes
   with `Behavior` (Motion.glide) or a short settle animation.
7. Wire row highlights: give each part a `StageSpot { keys: [...] }` with
   the keys (prefixes) of the rows that change it. A spot must not sit
   inside a `StyledRect` (it clips its children): put it beside the part
   (`anchors.fill: part`). Macro rows point with their macro's keys.
8. Move the page's `preview`s into the stage (or drop them) and remove
   under-row previews from the page's window entries.
9. No grey dead ends: an `enabledWhen` row either has a single switch
   (the row offers [Turn on]) or is hidden while it waits.
10. Translations for every new / changed key in en, es and ru. Remove keys
    that became unused (the translations audit warns).
11. Render the page in the five languages, dark and light, and look at it:
    clipping, overlap, alignment, blank thumbs, contrast.
12. `make schema`, `make check`.

## STAGE COMPONENTS (frame-independent)
- `Stage` (stages/Stage.qml): `stageHeight`, default children = the
  miniature, `wallpaper` (URL), `barOpacity`, `radius`, `backdrop`. Only
  needs SettingsStore and the kit; any window frame can host it.
- `ScreenMini` (stages/ScreenMini.qml): fills its parent; `showWindows`,
  `showDock`, `showIsland`, `selectable`, `selectedPanel`, signal
  `panelPicked(index)`, `barOpacity`, `cornerRadius`, default `overlay`
  children in screen coordinates; read-only geometry `unit`, `freeRect`,
  `islandRect`, `depths`, `edgeDepth(edge)`, `panels`, `sketches`.
- `StageSpot`: `keys`, `spread`, `cornerRadius`; lit while
  `SettingsStore.focusKeys` (set by `SettingsStore.point(owner, keys)` /
  `unpoint(owner)`) matches a key by prefix.
- Picture cards: `ChoiceCard` (`selected`, `title`, `subtitle`, `icon`,
  `previewHeight`, default = picture, `clicked()`), `CardSelector`
  (`entry` with `thumb`, `options`, `value`, `selected(value)`; pictures
  built asynchronously), thumbs (`entry`, `value`) on `MiniScreen` (`u`,
  `barOpacity`).

## MACROS
Look > Feel (`schema/macros.js`): Motion, Density, Roundness, Depth, Glass.
`Macros.js` (pure, tests/settings-macros.test.cjs) lists each macro's keys and
points; the slider shows the point every key matches, else "Custom". Moving
it writes only the keys that differ, as one undo step. Defaults must sit on
a point. The keys a macro moves are not rows of their own.

## SEARCH / CHANGES PAGE
The sidebar search covers window rows only (`SchemaUtil.buildSearchIndex`
skips out-of-window entries); a result names its destination and tab and
lands on the row (scroll, accent wash, keyboard focus). `Synonyms.js` (en +
ru) maps words people type to the words the schema uses. The Changes tab
(Presets) lists window rows that differ from their defaults or the preset.

## VERIFY
- `make check`: the `settings-schema` audit (keys / defaults, translations,
  options / ranges, conditions, registry), node tests
  `tests/settings-{window,undo,tree,schema,pages,changes,core,synonyms,macros}.test.cjs`,
  `tests/write-throttle.test.cjs`, QML tests `tests/settings-shell.test.py`
  (undo, tabs, keep-alive, stage spots, dead ends, search),
  `tests/settings-ui.test.py` (typed rows on every page),
  `tests/settings-load-stable.test.py`, `tests/settings-regressions.test.py`,
  `tests/config-file-autosave.test.py` (coalesced writes).
- Separate process: `tests/separate-windows.test.py`, `tests/preview-staging.test.py`
  (the wizard's relay), `tests/window-entries.test.py`, `tests/onboarding-*.test.py`.
- Tests that open the whole shell end with `h.exit(...)`: kept-alive pages
  must not outlive the singletons at interpreter teardown.
