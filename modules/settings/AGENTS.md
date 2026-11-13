# SETTINGS KNOWLEDGE BASE

## OVERVIEW
The settings window (`SettingsWindowInProcess.qml`, loaded by `shell.qml`, or
its own process with `performance.separateWindows`, see SEPARATE PROCESS) is
the shell's showpiece and is schema driven: settings are *declared* in
`schema/*.js` and rendered by generic components. Every change applies at
once and can be undone; there is no Apply step.

The frame is a **showcase** over an **ambient** background (kit Ambient:
the wallpaper blurred, darkened and vignetted; at full strength only at
home and on desktop pages, toned down on the others). It opens on a home
screen (the brand, one big search "What do you want to change?", undo and
nine equal destination tiles in a 3x3 grid, each a small live scene, its
name and one plain status line) and a tile grows into its destination. A
destination page is one scrolling column of cards: a round back button,
the title, the tabs and undo stay on top; under them a compact **stage**
(a third of the page at most) only where the desktop is the subject, a
one-line hint, then every card of the tab (no "More" sheet; the stage
recedes as the page scrolls). Search, modified / reset state, the CLI /
MCP catalog and the audits are all generated from the same declarations.

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
├── SettingsHome.qml        brand, search (window rows, value shown), undo, the 3x3 tile grid, preset footer
├── HomeTile.qml            one destination tile (kit Card): its scene (home/<X>Scene.qml, by URL), name, status
├── home/                   tile scenes: Layout (ScreenMini; the only one on the wallpaper), Look, Windows,
│                           Launcher, Notif, Assistant, Keys, Displays (plain monitors), System; NameScrim
├── HomeStatus.js           pure: the tile's one live status line (tests/settings-home.test.cjs)
├── HomeLayout.js           pure: home columns, tile packing, arrow-key neighbours (same test)
├── DestinationHeader.qml   back pill, title, centred tabs (kit Segmented), Reset page
├── SettingsPageHost.qml    creates pages by URL on first visit, keeps the last 4 (PageCache.js)
├── SettingsPage.qml        a schema category: compact stage (by URL, recedes on scroll), hint, card bento
├── FittedFrame.qml         measures of the hand-written one-screen pages (Displays, Keyboard, About)
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
├── Registry.js             names -> files: EDITORS, PREVIEWS, THUMBS, STAGES, PAGES; DESKTOP_STAGES (the
│                           tabs whose subject is the desktop), PLAIN_STAGES (stages on a plain ground)
├── stages/                 Stage.qml (frame; `calm` = plain card fill, no wallpaper), ScreenMini.qml,
│                           StageSpot.qml, EdgePicker.qml; desktop stages Bar, Island, Dock, Desktop,
│                           Lock, Notif, Osd, Windows, Wallpaper; plain stages Power, Updates, Terminal
│                           and the list bands <X>Band.qml (Network, Bluetooth, Sound, Effects, Keys,
│                           Providers, Routines); pure helpers WindowTiles / DesktopPlace / OsdPlace /
│                           KeyDeck.js (node-tested)
├── thumbs/                 picture-card thumbs (MiniScreen.qml: the wallpaper screen they draw on)
├── controls/               typed controls (Toggle, Slider, Selector, Number, Text, Font, ColorRole,
│                           List, Path, Screens, Chips, Macro) + ChoiceCard, CardSelector
├── editors/                rich `custom` editors (one file each, `property var entry`); PageCard +
│                           CardScroll: a hand-written one-screen page's card and its scrolling body
├── previews/               old under-row previews (`preview`), for pages not converted yet
├── schema/Categories.js    information architecture: destinations, tabs, HOME tiles, MOVED, resolve();
│                           withSections / withEntries / withoutSections / sectionsOf compose tabs
├── schema/<category>.js    one file per category (a tab of a destination)
├── store/SettingsStore.qml get / set (live + undo) / stageSet (wizard) / reset / focusKeys / navigate
├── store/PresetStudio.qml  preset studio data + actions (`<app> preset ...`)
├── presets/, displays/, keyboard/, extras/, mods/, changes/, system/  hand-written pages
├── connect/                live device lists of the Network, Bluetooth and Sound tabs (ConnectModel.js)
└── Macros.js, Synonyms.js  pure: macro sliders' key mapping; search synonyms (en + ru)
```

## LOOK
Built only from the kit (`qs.modules.components.kit`); no raw sizes, colors
or Rectangles/Texts (`kit-literals` ratchet: a new directory must be at
zero; draw shapes of a miniature with `Mark`, surfaces with `StyledRect` and
the theme's variants). The window must look deliberate in every visual
language (ink, glass, tiles, classic, device) and in dark and light; nothing
branches on the language name (`Look`).
- Window background: kit `Ambient` (`source` = `SettingsStore.wallpaper`,
  decoded tiny, blurred once into a cached layer, darkened, vignetted, a new
  wallpaper cross-fades in; `plain` on battery saver). How much shows is
  the language's (`VisualLanguage` `card.ambient` -> `Look.ambientStrength`).
- Surfaces: kit `Card` = `Look.cardFill` / `cardEdge` / `cardShadow`
  (VisualLanguage `card`: translucent with a hairline in ink and glass,
  solid in tiles / device / classic, a soft RectangularShadow); `accented`
  rings and glows the card the screen is about.
- Home: header (brand, a boxed `SearchField`, undo), then the nine
  destination tiles in a 3x3 grid (`HomeLayout.columns`: 3, or 2 in a
  narrow window with a 15 % hysteresis; equal tiles, `Look.screenGap`
  between them and around), then the preset footer. Each tile is a kit
  `Card` (`interactive`: lifts on hover, springs on press, FocusRing) with a
  scene from real state (home/*.qml, `required property Card tile`). Only
  the Screen tile draws the wallpaper (it is about the desktop); the others
  are plain: palette + "Aa", a toast stack, a launcher, a chat, keycaps,
  the monitor arrangement as plain shapes, tiled windows, the version and
  language. Name = `title` role, status one size down (`secondary`), plain
  words (HomeStatus.js). A scene must not declare a property named like an
  Item anchor line (`top`, `bottom`, `left`, `right`, ...): it hangs the
  type loader.
- Opening: a box grows from the tile to the window (Motion.glide) while
  home recedes and the page fades in; going back reverses it. A deep link
  (`<app> run settings <id>`, `GlobalStates.settingsCategory` at open)
  opens straight on its page with no motion.
- Destination: `DestinationHeader` = back pill (IconButton), title role,
  the tabs centred (`Segmented`, `focusable`, Left / Right), Reset page on
  the right; a tab to the right slides the page in from the right
  (`SettingsPageHost.direction`).
- Page body (SettingsPage): the stage (a `Registry.DESKTOP_STAGES` tab:
  16:9, at most a third of the page; a `PLAIN_STAGES` one: a wide strip on
  the card fill; a list page's band: a fifth of the page), one hint line
  (two at most in a narrow window), then every card of the tab in a bento
  (`BentoLayout.js`, 1 to 3 columns with hysteresis, never more columns
  than the cards fill). Cards size to their content; the page scrolls.
  The lead sections (`row`) come first. A card (SettingsSection) has a
  heading (`title` role) with the current value on the right when it holds
  one setting; such a card's picture / editor row drops its own label
  (`SettingRow.bare`).
- Rhythm (one set of kit tokens, everywhere): page side margin `Space.xl`;
  the gap between cards, between stage / hint / cards and between home
  tiles `Look.screenGap`; inside a card the kit Card padding, the heading
  then the rows at the same distance in every card; rows are dense
  (`Space.xs` above and below), label left and control right on one line,
  the control as wide as its content (measured: a segmented, dropdown or
  font name is never cut, it goes under its label instead); the header is
  one centred line (its tabs take a line of their own, scrolling sideways,
  when they would run under the title or undo).
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
Render: `tools/render/settings_render.py --wallpaper assets/wallpapers_example/wallpaper-01.png --palette default
--languages ink,glass,tiles,classic,device [--mode light] [--size 1180x2400] home|PAGE...`
(`home` with `--search Q` shows results, `--hover ENTRY` lights a stage part,
`--undo` shows the pill, `--eval barEdgePicker:preview='left'` a hovered
edge).
`--devices`: believable live services for the device pages
(`tests/lib/device_fixtures.py`: a laptop battery and profiles, two monitors,
two keyboard layouts, Wi-Fi networks, Bluetooth devices, speakers and a
microphone with apps playing, fish prompts with previews, the extras
catalog) and, after `make build`, the presets the built app lists;
`SettingsEnv(..., devices=True)` gives tests the same world. With
`--wallpaper`, the library gets small thumbnails like the manager's cache.
Colours come from the wallpaper (matugen, or `tools/render/wallpaper_palette.py`
with the `materialyoucolor` package) unless `--palette default` (the rose
palette, which belongs with wallpaper-01). Motion: `tools/render/settings_motion.py [tile-hover tile-open
edge-click]` writes animated WebP + GIF at real speed.

## NAVIGATION
`schema/Categories.js`: `groups` are the nine destinations, each `{id,
icon, title: prefs.dest.<id>, categories: [tab ids]}`:
Look (Theme & colours, Wallpaper, Fonts & icons, Presets, Changes) |
Screen (Bar, Island, Dock, Widgets & clock, Lock screen) | Windows (Layout
& gaps, Overview, Special workspaces) | Panels (Launcher, Dashboard, Menus
& OSD) | Notifications & focus (Notifications, Timers & focus) | Assistant
(Chat, Models & providers, Agents & tasks, Voice) | Keyboard (Layouts,
Shortcuts) | Devices (Displays, Network, Bluetooth, Sound, Effects, Power) |
System (Language & weather, Updates, Terminal, Apps, Mods, Routines,
About). `HOME` = the groups in that order (nine equal tiles); `home()` the
model. A category is one tab: its `title` is the tab label. Tabs are
composed from schema files: `withSections` (Menus & OSD gets the OSD
sections, Bar the bar builder of layout.js, Chat the sidebar sections),
`withEntries` (each "Opens in" row of layout.js placed first on the page of
what opens: launcher, dashboard, the shortcut sheet on Shortcuts, quick ask
on Chat, the voice / timers panel on Timers & focus, sheet side and
backdrop on Menus & OSD), `withoutSections` / `sectionsOf` (OCR languages
from updates.js on Language & weather). "Where things open" no longer
exists. `resolve(id)` accepts a category id, a `MOVED` id (merged pages,
former destinations: `layout` -> bar, `osd` -> menus, `wallpaper`,
`apps`, `fonts`, `island`, `popups`, ...) or a destination id (its first
tab), so `<app> run settings <id>`, `GlobalStates.settingsCategory` and old
deep links keep working. `tabsOf(categoryId)`, `groupOf(categoryId)`,
`ordered()` (Ctrl+Tab order).
One setting is one row in one place: a neighbouring page that wants it gets
a PageLink row (`type: "custom"`, `component: "PageLink"`, `target`,
`targetSection`, `linkText`): Island links to the notification and timer
looks, Voice to where its panel opens.
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
  the pill, and the pill undoes the step it names, by its id (never a
  newer one). A key with no entry of its own is named by its parent entry.
  A step whose keys no longer hold its "after" value (something outside
  the window changed them) is dropped, never replayed over the newer value.
  The history clears on preset apply / try / keep / revert, on a preset
  edit's save or cancel, on an external reload that changed a value the
  history expects, and when the window closes.
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
  on the window's first `frameSwapped`): the tile scenes (home/*.qml, by
  URL, asynchronous, one more per frame: Stage and ScreenMini compile only
  then), the tile status lines and their services (network, audio,
  updates), the preset footer (PresetStatusService) and the
  preset overlays of the shell (edit banner, trial pill, toast, changes sheet,
  name dialog: Loaders by URL, asynchronous, compiled off the first frame). The search
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
id: the row notes "Island is off - shown as X"; the stage draws it).
`lazy: true` (a heavy custom editor in a card of the page row: compiled and
built on the frame after the page shows, asynchronously; the card height is
fixed, so nothing moves). `part: true` (an editor of one part of a composite value that another entry
also edits, e.g. the bars list beside the stage and the selected bar's
fields; exempt from the one-control check).
Section fields: `id`, `title`, `entries`, `toggle` (the key of a switch of
the section drawn in the card's heading, for a card that is the thing it
turns on: Special workspaces), `advanced: true` (the whole section
is out of the window), `compositor`, `span`. A section shows only while one
of its rows does. Category fields: `id`, `icon`, `title` (the tab label),
`description`, `keywords`, `sections`, `stage` (Registry.STAGES name) or
`page` (Registry.PAGES name), `hero` (`{left: [key|id], right: [key|id],
hint: i18n key}`: entries shown beside the stage instead of in their card),
`row` (section ids: the row of cards under the stage).

Control mapping (applied everywhere): on / off -> `toggle` (Switch);
2 to 5 visual options -> `selector` + `display: "cards"` + `thumb`;
2 to 4 non-visual options -> `selector` (kit Segmented); more -> `selector`
(kit Dropdown); continuous -> `slider` in human units; a small count ->
`number` (stepper); a font -> `font` (the picker; `sizeKey` adds the size).

## PAGE COMPOSITION (the template; the rules for every page)
A page is one scrolling column: header (DestinationHeader, outside the
scroll: always visible, undo included), then the stage, the hint and every
card of the tab. Nothing hides in a sheet; the page scrolls.

- Previews are the thing itself, big and readable, never a shrunk desktop
  where the desktop is not the subject. Strip stages (`pageWide: true`,
  `preferredHeight`): the Bar (ScreenMini drawn page-wide and cropped to
  the bar: the real clock face and workspace indicator, every module
  glyph; a click on a module scrolls to and flashes its card), the Island
  (drawn big in its shape, a state picked with chips: at rest, music,
  notification, timer), the Dock (the real indicator styles, magnification
  on hover), and on a plain ground the Launcher, the Dashboard, the Chat,
  a notification (a toast at its real size, grouped, from the island or
  as a strip; with corner toasts a small screen whose corners move them)
  and the real OSD beside a bar menu in the popup style (a small screen
  whose edges move the OSD). Where a thing sits is its Edge row, not the hero. Every StageSpot
  flashes briefly when one of its keys changes. settings-fit wants the
  smallest glyph on the bar, island and dock strips at 10 px or more.
- Picture cards: compact (controls/PictureGrid.js: about 96 to 150 px,
  five or six a row in a wide card, wrapped, never clipped), the object
  drawn on a plain ground (thumbs/MiniScreen `desktop: false`,
  thumbs/ThumbGround); the wallpaper only where it is the subject (fit,
  transition) and in real captures (lock styles, presets). Names wrap to
  two lines, the chosen one ringed, checked and on a tonal fill; a compact
  card's description is its tooltip.
- Order: the card of the tab's master switch (`<feature>.enabled`) first,
  then cards of plain rows, then those of a big control (pictures, an
  editor, a list), the lead (`row`) ones first in each (BentoLayout.order).
- Placement (BentoLayout.place): each card goes to the highest free place
  that holds it (the shortest column, or a hole beside a wide card); among
  equal places, the one that lifts the shortest column. Once the page is
  whole a card keeps its column (a toggle moves it up or down, never
  across). A card is one column unless it holds a wide editor
  (BentoLayout.WIDE_EDITORS) or a picture choice of more than three
  options (two columns, six pictures a row); a page with as many wide
  cards as narrow ones uses two columns, and the columns share the page's
  width. The layout probe fails on an empty column (three or more cards)
  or a column ending more than about a card above the tallest while cards
  remain below the fold.
- One thing once: no card holds a single plain row (Categories.mergeInto
  folds it into the card it belongs with; moveEntry puts a feature's switch
  at the head of its card), a card header shows no value summary (the
  card's control shows it), a row is never named like its card, labels are
  in sentence case (tests/settings-page-unique.test.cjs). Translated text
  wraps, never elides; only data (file, network, model names) may. settings-fit counts the whole rows on the
  first screen (8 with a stage, 14 without); the tabs still short of it are
  a ratchet (`SHORT`).
- `stage` (category): only a tab whose subject is the desktop has a
  desktop stage (a `Registry.DESKTOP_STAGES` entry: Bar, Island, Dock,
  Widgets & clock, Lock screen, Notifications, Menus & OSD, Windows,
  Wallpaper; tests/settings-page-unique.test.cjs keeps the list). Another
  tab gets a stage only when it shows the thing itself and holds a control
  found nowhere else (Power: battery and profiles; Updates: state and Check
  now; Terminal: the terminal window) or a list page's band; these are
  `PLAIN_STAGES`, drawn on the card fill (`Stage.calm`), never on the
  wallpaper. A tab where a miniature explains nothing has no stage.
- `hero.hint`: one line under the stage saying what a click on it does.
  `hero.foot`: a strip along the stage's foot (Wallpaper's library).
- `row`: the lead section ids: those cards come first (the 3 to 5 most
  changed settings). Every other section follows in the bento.
- `form: "list"`: the stage is a short band (a fifth of the page) over the
  list's cards.
- Cards: grouped by meaning, labels unique within a page (tested in every
  language), no setting twice on a page. A card waiting on one switch
  (CardGate) shows its rows dimmed and offers "Turn on" only when that
  switch is not a row of the same page (`SettingsSection.offersTurnOn`); a
  row hidden until a switch of the same page is on stays hidden.
- Picture choices (`display: "cards"`) are always pictures, wrapped so
  every option is visible (CardSelector); only a strip of more than eight
  scrolls sideways (fades, the chosen one scrolled into view).
- Motion: a card that moves up glides into the room; when one is pushed
  down every card lands at once (no frame where a card sits under
  another); relayout is synchronous with a card's height change.
- entry `part: true`: an editor of one part of a composite value that
  another row also edits, or the window's control of a key another page
  owns (Windows' Corners card: Look's `compositor.rounding`); it declares
  the keys it writes in `keys` (tests/settings-pages.test.cjs).

Hand-written one-screen pages (Displays, Keyboard, About; `fitted: true`)
keep their FittedFrame layout; under ~820 px they stack their cards one a
line and scroll (`stackable`, `stacked`, `stackedHeight`; FittedFrame is a
Flickable that only scrolls then: a page must not declare `contentHeight`).

Making a stage: `stages/<Name>Stage.qml` with a `Stage` root, registered
in `Registry.STAGES` (and in `DESKTOP_STAGES` or `PLAIN_STAGES`). For
anything placed on the screen use `ScreenMini` and draw your part in its
overlay with its geometry (`freeRect`, `islandRect`, `edgeDepth`, `unit`).
Direct manipulation: EdgePicker (edges), dashed zones (kit `DashedFrame`)
for places, `partsClickable` for the island / dock; write through
`SettingsStore.transaction("prefs.undo.<x>_moved")`; keep the row too (it
is the keyboard path).

Check one page offscreen:
`tools/render/settings_render.py --wallpaper assets/wallpapers_example/wallpaper-01.png
--palette default --languages ink --mode dark <category>`; then
`python3 tests/settings-fit.test.py`.

## CONVERTING A PAGE (checklist for the remaining destinations)
Every schema page already renders in the template (stage where allowed +
card bento); converting means curating it.
Reference pages: Screen (`schema/bar.js`, `notch.js`, `dock.js`;
`stages/BarStage.qml`, `IslandStage.qml`, `DockStage.qml`),
Notifications (`stages/NotifStage.qml`) and Look (`schema/appearance.js`,
`icons-type.js`: no stage, picture cards).
1. Budget: about 8 to 15 rows a tab (the window ~280 in all). Count with
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
   with the bars editor). Ghost targets show the places of a part: the
   hovered / just-changed one solid and named (no label is ever drawn over
   another). The stage file is `stages/<Page>Stage.qml` with a
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
6c. Composition: the stage (desktop tabs only), its hint, the lead cards
   (`row`), then the rest. Sections are the cards: a short title (two
   words), one concept each; `"span": 2` when the content needs the width.
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
- Shortcuts: a KeyRecorder shares the keys it has while it records
  (`KeybindsStore.recordingDraft`); the Keys band lights them as they are
  pressed.
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
lists every shown setting that differs from its default or the preset:
window rows with a jump to their row, out-of-window ones (advanced) without
a jump; "Reset page" keeps the window filter (ResetModel.changedItems).

## VERIFY
- `make check`: the `settings-schema` audit (keys / defaults, translations,
  options / ranges, conditions, registry), node tests
  `tests/settings-{window,undo,tree,home,schema,pages,page-unique,changes,core,synonyms,macros}.test.cjs`
  (page-unique: no key or label twice on a page in en / es / ru, Opens-in
  rows on the page of what opens, the desktop-stage list),
  `tests/write-throttle.test.cjs`, `tests/settings-undo-steps.test.cjs`,
  `tests/settings-save-path.test.cjs`, `tests/settings-changes-all.test.cjs`,
  `tests/settings-undo-store.test.py`, `tests/config-file-restore.test.py`,
  `tests/preset-studio-restore.test.py`, QML tests `tests/settings-shell.test.py`
  (undo, tabs, home / back, keep-alive, stage spots, dead ends, search),
  `tests/settings-ui.test.py` (typed rows on every page),
  `tests/settings-load-stable.test.py` (home first frame, deep link, no card
  moves once a page shows, home reflow), `tests/settings-regressions.test.py`,
  `tests/preset-status-footer.test.py`, `tests/config-file-autosave.test.py`.
- Layout: `tests/lib/settings_probe.py` (overlap of cards, rows, header
  parts, stage / hint / cards, home tiles; elided or overflowing text;
  picture options out of reach; stage size) drives
  `settings-fit` (1180x780, every tab, after gates / selectors / long
  values, no binding or polish loop, first-screen density, strip glyphs), `settings-fit-min` (640x480, ru),
  `settings-fit-large` (1600x1000, es), `settings-fit-looks` (every visual
  language, dark and light), all with the bundled UI fonts pinned
  (`SettingsEnv(pin_fonts=True)`: Inter and IBM Plex Mono, the same glyphs
  on every machine) and every kit text 20 % wider (`text_wider=0.2`); `settings-stability` (nothing moves 0 / 200 ms
  / 1 s / 2 s after a page shows, nor on hover) and `settings-resize`
  (columns switch once each way). Page tests: `settings-personal`,
  `settings-system-pages`, `settings-assistant-pages`, `settings-changes-page`,
  `settings-connect`, `settings-keys`, `settings-power`, `settings-windows-stage`,
  `settings-displays-flow` (`.test.py`), `settings-bar-shape.test.cjs`.
- Separate process: `tests/separate-windows.test.py`, `tests/preview-staging.test.py`
  (the wizard's relay), `tests/window-entries.test.py`, `tests/onboarding-*.test.py`.
- Tests that open the whole shell end with `h.exit(...)`: kept-alive pages
  must not outlive the singletons at interpreter teardown.

