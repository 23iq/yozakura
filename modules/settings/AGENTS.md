# SETTINGS KNOWLEDGE BASE

## OVERVIEW
The settings window (`SettingsWindowInProcess.qml`, loaded by `shell.qml`, or
its own process with `performance.separateWindows`, see SEPARATE PROCESS) is
the shell's showpiece and is schema driven: settings are *declared* in
`schema/*.js` and rendered by generic components. Every change applies at
once and can be undone; there is no Apply step.

The frame is a **showcase**: it opens on a home screen (the brand, one big
search "What do you want to change?", a bento of live tiles, a row of pills)
and a tile grows into its destination. A destination page has no chrome but
a back pill, its title and centred tabs; its body is a **hero** (the stage:
a live miniature of what the tab controls, which you can also click to
change things) over a **bento of cards** (one per schema section). Search,
modified / reset state, the CLI / MCP catalog and the audits are all
generated from the same declarations.

Design rules (owner's brief, binding for every page; in this order: clear,
then beautiful, then interactive):
- Only the important options are rows of the window. Rare knobs stay in the
  schema with `advanced: true` (reachable through `yozakura config`, MCP and
  presets, never rendered, never found by the window's search).
- No text walls: a row is a short sentence-case label (two to four words)
  and its control. The description is the label's tooltip, never printed.
  A one-line `hint` (eight words at most) only where the effect cannot be
  seen on the stage.
- Visual by default: the stage reacts to every row; a choice between looks
  is a row of picture cards; where a thing sits on the screen, you pick the
  place on the miniature (direct manipulation).
- One control per setting, one name per concept (the Island, not the notch).
- Motion explains, never decorates: hover lifts, a tile grows into its page,
  a moved part glides to its new place; nothing animates while idle.

## STRUCTURE
```
modules/settings/
├── SettingsWindow.qml      FloatingWindow wrapper (placement on the focused workspace, re-homing)
├── SettingsWindowInProcess.qml  + SettingsShell, static (shell.qml KeepAliveLoader)
├── SettingsWindowSeparate.qml   + SettingsShell by URL, async, behind SettingsLoading (settings-window.qml)
├── OpeningPill.qml         main shell: "Opening Settings..." while a window process starts
├── SettingsShell.qml       the frame: home <-> destination (shared-element growth), shortcuts,
│                           UndoPill, preset overlays; select / openDestination / goHome / navigate
├── SettingsHome.qml        brand, search (window rows, value shown), tile bento, pills, preset footer
├── HomeTile.qml            one destination tile (kit Card): icon or picture, name, live status
├── HomeTileArt.qml         a picture tile's art (wallpaper Stage, the Desktop layout ScreenMini), by URL
├── HomeStatus.js           pure: the tile's one live status line (tests/settings-home.test.cjs)
├── HomeLayout.js           pure: home columns, tile packing, arrow-key neighbours (same test)
├── DestinationHeader.qml   back pill, title, centred tabs (kit Segmented), Reset page
├── SettingsPageHost.qml    creates pages by URL on first visit, keeps the last 4 (PageCache.js)
├── SettingsPage.qml        a schema category: hero stage (by URL, recedes on scroll) + card bento
├── BentoLayout.js          pure: page columns, card spans, masonry places / floor (same test)
├── SettingsSection.qml     one section as a kit Card of SettingRows (window entries only)
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
│                           StageSpot.qml (highlight), EdgePicker.qml (move a part by its edge),
│                           <Page>Stage.qml (Bar, Island, Dock, Opens, Notif, Look, Type)
├── thumbs/                 picture-card thumbs (MiniScreen.qml: the wallpaper screen they draw on)
├── controls/               typed controls (Toggle, Slider, Selector, Number, Text, Font, ColorRole,
│                           List, Path, Screens, Chips, Macro) + ChoiceCard, CardSelector
├── editors/                rich `custom` editors (one file each, `property var entry`)
├── previews/               old under-row previews (`preview`), for pages not converted yet
├── schema/Categories.js    information architecture: destinations, tabs, HOME tiles, PILLS, resolve()
├── schema/<category>.js    one file per category (a tab of a destination)
├── store/SettingsStore.qml get / set (live + undo) / stageSet (wizard) / reset / focusKeys / navigate
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
- Home: the brand (sakura mark tinted with the accent + "Settings"), a boxed
  `SearchField` (620 px), the bento (`HomeLayout.js`: 6 / 4 / 2 columns by
  width, tiles big 2x2 / wide 2x1 / small 1x1, first-fit in reading order),
  then the pills (kit `Chip`, quiet) and the preset footer. Tiles are kit
  `Card`s (`interactive`: lift `Space.xs` and brighten on hover, spring on
  press, FocusRing); Desktop layout is the real `ScreenMini` on your
  wallpaper (windows slide in on hover), Wallpaper is the wallpaper (it
  swells and follows the pointer: `Card.pointer` -> `Stage.imageShift`),
  Look shows palette swatches; the others an accent icon. Each tile carries
  its name (`title`) and one live status line (`secondary`).
- Opening: a box grows from the tile to the window (Motion.glide) while
  home recedes and the page fades in; going back reverses it. A deep link
  (`<app> run settings <id>`, `GlobalStates.settingsCategory` at open)
  opens straight on its page with no motion.
- Destination: `DestinationHeader` = back pill (IconButton), title role,
  the tabs centred (`Segmented`, `focusable`, Left / Right), Reset page on
  the right; a tab to the right slides the page in from the right
  (`SettingsPageHost.direction`).
- Page body: the hero stage (at most 760 px wide, centred) that scales down
  and fades as the cards scroll over it (`recede`), then the bento: one kit
  `Card` per section, its title as the card label, packed by
  `BentoLayout.js` in 1 to 3 columns (a card with picture cards, an editor,
  a list or `"span": 2` takes two; a page whose cards are all wide uses two
  columns, centred, instead of leaving a third empty).
- Rows: label `body`, control flush right (inline) or full width under the
  label (cards, editors, lists, and sliders / selectors / text fields in a
  narrow card); hover / focus = the language's hover box; a search jump =
  accent wash + focus.
- Picture cards: `ChoiceCard` - the picture is the card (rounded mask, a
  hairline edge, lifts on hover); selected = accent ring + title in the
  active weight + check; FocusRing on keyboard focus.
- Stage: `Stage` = wallpaper (palette backdrop without one) in a rounded,
  hair-lined frame, Look.radius("surface"); the miniature on top.
- Undo pill: popup surface, springs in, stays 5 s (longer while hovered).
Render: `tools/render/settings_render.py --wallpaper assets/wallpapers_example/wallpaper-03.png
--languages ink,glass,tiles,classic,device [--mode light] [--size 1180x2400] home|PAGE...`
(`home` with `--search Q` shows results, `--hover ENTRY` lights a stage part,
`--undo` shows the pill, `--eval barEdgePicker:preview='left'` a hovered
edge). Motion: `tools/render/settings_motion.py [tile-hover tile-open
edge-click]` writes animated WebP + GIF at real speed.

## NAVIGATION
`schema/Categories.js`: `groups` are the destinations, each `{id, icon,
title: prefs.dest.<id>, categories: [tab ids]}`. `HOME` lists the bento
tiles in reading order with a size (`big` / `wide` / `small`): Desktop
layout (Bar, Island, Dock, Where things open; big), Look, Wallpaper (wide),
Presets, Notifications (+ On-screen display, Menus), Lock screen,
Assistant, Launcher, Dashboard, Desktop, Keys (Keyboard, Shortcuts),
Displays, Windows; `PILLS` the plain system ones under it: Network, Sound,
Power, Apps, System. `home()` / `pills()` are the models. A category is one
tab: its `title` is the tab label (one to three words). One tab = no tab
strip. `resolve(id)` accepts a category id, a `MOVED` id (merged pages,
former sidebar groups such as `popups`, `island`) or a destination id (its
first tab), so `<app> run settings <id>`, `GlobalStates.settingsCategory`
and old deep links keep working. `tabsOf(categoryId)`, `groupOf(categoryId)`,
`ordered()` (Ctrl+Tab order).
A category is either schema driven (`sections`, rendered by SettingsPage) or
a hand-written page (`page`: a `Registry.PAGES` name, loaded by URL).
Shell API (SettingsShell): `select(id)` (any id `resolve` takes),
`openDestination(id, fromItem)`, `goHome()`, `openSearch()`,
`navigate(category, section, entry)` (also `SettingsStore.navigate`, which
any stage or editor may call), `atHome`, `currentCategory`. Keys: typing on
home searches, arrows move between tiles, Enter opens; Esc / Alt+Left / the
mouse back button / the back pill return home; Ctrl+F searches; Ctrl+Z /
Ctrl+Shift+Z undo / redo; Ctrl+Tab steps through tabs.

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
- Opening the window at home builds no page: the tiles read config only.
  What the first frame does not need waits for it (`SettingsHome.warm`, set
  on the window's first `frameSwapped`): the picture tiles (`HomeTileArt`,
  by URL, asynchronous: Stage and ScreenMini compile only then), the tile
  status lines and the preset footer (PresetStatusService). The search
  index is built on the first query (or when the changes sheet opens).
- Pages and stages are created by URL (`Registry.PAGES`, `Registry.STAGES`);
  the host imports the page directories only so Quickshell's scanner
  reaches them. Never name a page or stage type statically in the shell or
  on home.
- The last 4 visited pages stay alive, hidden and disabled (PageCache.js);
  a revisit shows the same page at once. Rows of a hidden page point at
  nothing. Keep stages cheap while hidden (no endless animations; a stage
  that animates should gate on `visible`).
- SettingsPage builds its sections a few per frame and stays hidden until
  every bento column reaches below the viewport (`BentoLayout` floor: the
  cards still to come land out of sight), then enters; it relayouts the
  bento synchronously each build frame so no card moves once shown. No row
  object exists for an out-of-window entry.
- Heavy live previews become pictures: the lock screen gallery builds one
  LockView at a time, captures it (`grabToImage`) and destroys it.
- Measure with the audit harness (scratch scripts based on
  `tests/lib/settings_env.py`: window load to the first `frameSwapped` for
  home; `select()` to the host's `pageReady` and to `item.complete` for a
  page). Compare with an empty window in the same harness (its fixed cost).

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
Every schema page already renders in the new frame (hero + card bento);
converting means curating it and giving it a stage worth looking at.
Reference pages: Desktop layout (`schema/bar.js`, `notch.js`, `dock.js`,
`layout.js`; `stages/BarStage.qml`, `IslandStage.qml`, `DockStage.qml`,
`OpensStage.qml`), Notifications (`stages/NotifStage.qml`) and Look
(`schema/appearance.js`, `icons-type.js`, `stages/LookStage.qml`,
`stages/TypeStage.qml`).
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
6b. Direct manipulation: where a part sits is chosen ON the miniature.
   An edge choice gets an `EdgePicker` in the ScreenMini overlay (`edges`,
   `current`, `busy`, `reach`, `ghostThickness`, `ghostSpan`, signal
   `picked(edge)`: hover shows a ghost and "Move here"); a corner / place
   choice gets ghost targets like NotifStage (hover shows the thing there,
   click moves it); `partsClickable` + `partPicked(part)` makes the island
   and the dock open their tab (`SettingsStore.navigate`). Write through
   `SettingsStore.transaction("prefs.undo.<thing>_moved", ...)`: a
   `prefs.undo.*` label names itself in the undo pill ("Bar moved"). Keep
   the row (cards / segmented) too: it is the keyboard path.
6c. Cards: sections are the cards; give a section a short title (two
   words) and keep a card to one concept. `"span": 2` on a section when its
   content needs the width and BentoLayout.spanOf does not see it.
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
  miniature, `wallpaper` (URL), `barOpacity`, `radius`, `backdrop`,
  `imageScale`, `imageShift` (parallax). Only needs SettingsStore and the
  kit; any frame can host it (the page hero and the home tile use the same).
- `ScreenMini` (stages/ScreenMini.qml): fills its parent; `showWindows`
  (fades / slides), `showDock`, `showIsland`, `corners`, `emphasis`
  ("island" | "dock": accent ring), `selectable`, `selectedPanel`, signal
  `panelPicked(index)`, `partsClickable` + signal `partPicked(part)`,
  `barOpacity`, `cornerRadius`, default `overlay` children in screen
  coordinates; read-only geometry `unit`, `freeRect`, `islandRect`,
  `islandEdge`, `depths`, `edgeDepth(edge)`, `panels`, `sketches`.
- `EdgePicker`: see CONVERTING 6b; `preview` forces a hovered edge
  (renders, tests).
- `StageSpot`: `keys`, `spread`, `cornerRadius`; lit while
  `SettingsStore.focusKeys` (set by `SettingsStore.point(owner, keys)` /
  `unpoint(owner)`) matches a key by prefix.
- Picture cards: `ChoiceCard` (`selected`, `title`, `subtitle`, `icon`,
  `previewHeight`, default = picture, `clicked()`), `CardSelector`
  (`entry` with `thumb`, `options`, `value`, `selected(value)`; pictures
  built asynchronously), thumbs (`entry`, `value`) on `MiniScreen` (`u`,
  `barOpacity`).
- Kit `Card` (modules/components/kit/Card.qml): the bento box of both home
  and pages; `label`, `interactive`, `fill`, `padding`, `spacing`,
  `contentWidth`, `background` (a picture under the content), `pointer`,
  `hovered`, `clicked()`.

## MACROS
Look > Feel (`schema/macros.js`): Motion, Density, Roundness, Depth, Glass.
`Macros.js` (pure, tests/settings-macros.test.cjs) lists each macro's keys and
points; the slider shows the point every key matches, else "Custom". Moving
it writes only the keys that differ, as one undo step. Defaults must sit on
a point. The keys a macro moves are not rows of their own.

## SEARCH / CHANGES PAGE
The home search covers window rows only (`SchemaUtil.buildSearchIndex`
skips out-of-window entries); typing anywhere on home starts it. A result
names its destination (and tab, section) and shows the row's current value;
Up / Down pick, Enter opens the highlighted one, Esc clears. It lands on the
row (scroll, accent wash, keyboard focus). `Synonyms.js` (en + ru) maps
words people type to the words the schema uses. The Changes tab (Presets)
lists window rows that differ from their defaults or the preset.

## VERIFY
- `make check`: the `settings-schema` audit (keys / defaults, translations,
  options / ranges, conditions, registry), node tests
  `tests/settings-{window,undo,tree,home,schema,pages,changes,core,synonyms,macros}.test.cjs`,
  `tests/write-throttle.test.cjs`, QML tests `tests/settings-shell.test.py`
  (undo, tabs, home / back, keep-alive, stage spots, edge / island / corner
  clicks, dead ends, search), `tests/settings-ui.test.py` (typed rows on
  every page), `tests/settings-load-stable.test.py` (home first frame, deep
  link, no card moves once a page shows, home reflow),
  `tests/settings-regressions.test.py` (narrow window search),
  `tests/preset-status-footer.test.py`, `tests/config-file-autosave.test.py`
  (coalesced writes).
- Separate process: `tests/separate-windows.test.py`, `tests/preview-staging.test.py`
  (the wizard's relay), `tests/window-entries.test.py`, `tests/onboarding-*.test.py`.
- Tests that open the whole shell end with `h.exit(...)`: kept-alive pages
  must not outlive the singletons at interpreter teardown.

