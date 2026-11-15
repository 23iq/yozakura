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
screen (the brand, one big search "What do you want to change?" that
turns into a command palette with breadcrumbs, a History button and the
nine destinations as a bento whose tile sizes follow their weight: Screen
and Look big, every tile a small live scene of its subject, each with its
name and one live status line) and the tile grows into its destination (a
shared element, home/MorphFrame). A destination page: a round back button,
the title, the tabs, History and ⋯ (Reset page) stay on top (a hairline
under them once the page scrolls); under them, on a wide window, the
destination grid of two equal columns, the same in every tab: the **stage**
holds the right one, sticky, with the **inspector** under it where there
is room (the pointed setting, else the tab's changes), while the cards
scroll in the left one (the Screen tabs: one whole-screen canvas kept
across the tabs, the tab's own stage as a loupe under it); a page without
a stage fills both columns with cards. Every tab ends with its folded
**More settings** card: the tab's advanced rows. Search, modified / reset
state, the CLI / MCP catalog and the audits are all generated from the
same declarations.

Design rules (owner's brief, binding for every page; in this order: clear,
then beautiful, then interactive):
- Only the important options are rows of the tab's cards. Rare knobs and
  plumbing are `advanced: true`: rows of the tab's More settings card at the
  page's end, folded (PageMore; built on its first open), found by search
  like any row (a jump opens the card). Every schema entry is reachable in
  the window (tests/settings-window.test.cjs).
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
│                           UndoPill; select / openDestination / goHome / navigate
├── PresetOverlays.qml      the preset overlays (edit banner, trial pill, toast, changes sheet, name
│                           dialog: Loaders by URL after the first frame) + presetAction
├── SettingsHome.qml        brand, search (window rows, value shown), undo, the weighted tile bento, preset footer
├── HomeTile.qml            one destination tile (kit Card): a scene (home/<X>Scene.qml, by URL; beside the
│                           name on a wide tile, above it on a squarer one) or, without one or room for it,
│                           its icon on a plate (`glyph`), name, status
├── home/                   tile scenes (Registry.SCENES, one per destination): Layout (ScreenMini on a
│                           monitor with a stand), Look (wallpaper + a card of the language, Aa, font, mode,
│                           palette), Panels (launcher at its host), Windows (tiling, gaps, border to scale),
│                           Notifications (toast stack, DND moon), Devices (battery / Wi-Fi / volume / BT
│                           rings), Assistant (chat + provider logo), Keys (keycaps of your layouts), System
│                           (sakura, version, channel, update badge); SceneModel.js (pure geometry),
│                           SceneScreen (the small screen); HomeResults (the search palette), MorphFrame
│                           (the tile <-> page shared element)
├── HomeStatus.js           pure: the tile's one live status line (tests/settings-home.test.cjs)
├── HomeLayout.js           pure: home columns (6 / 4 / 2), weighted tile packing (no holes), arrow-key
│                           neighbours (same test)
├── DestinationHeader.qml   back pill, title, tabs after it (kit Segmented `navigation`), History + ⋯ (PageMenu)
├── PageMenu.qml            the header's small menus (History steps, ⋯: Reset page, All changes)
├── HistoryMenu.qml         the History menu (header and home): steps by id (`undo:<id>`, undoTo)
├── PillButton.qml          a labelled text button (kit Chip; `kind`, `icon` = an Icons name)
├── EdgeFade.qml            fades a scrolling strip's cut edges with a mask (header tabs, strips)
├── SettingsPageHost.qml    creates pages by URL on first visit, keeps the last 4 (PageCache.js); tab switches
│                           as one two-page transition; the shared Screen canvas
├── SettingsPage.qml        a schema category on the destination grid (`wide`: two columns; `split`: the
│                           stage sticky in the right one, the inspector under it), the stage on top in a
│                           narrow window or a list page; the stage, the hint, the reveal (search jumps)
├── PageBento.qml           the page's cards: SettingsSection per section, masonry (BentoLayout.place)
├── PageMore.qml            the tab's folded More settings card (SchemaUtil.moreGroups: advanced rows)
├── PageInspector.qml       under the sticky stage: the pointed row (name, now / default, Reset) or the
│                           tab's changes (counted while shown, after changes settle); InspectorLine
├── HoverHint.qml           the stage's hint line (shows while the pointer is over the stage)
├── RectGlide.qml           glides an item to a rect on a discrete change, lands at once on a resize
├── FittedFrame.qml         measures of the hand-written one-screen pages (Displays, Keyboard, About)
├── BentoLayout.js          pure: page columns, card spans, masonry places / floor / widen / stretch (same test)
├── RowLines.js            pure: a card's rows in lines (picture rows side by side; settings-row-lines.test.cjs)
├── ControlColumn.js        pure: a card's control column and stepper readout (settings-control-column.test.cjs)
├── SettingsSection.qml     one section as a kit Card of SettingRows (card rows; `more`: a group of the
│                           More card, its advanced rows, unboxed)
├── SettingRow.qml          label (+ Tooltip, reset, caption) and the typed control; points the stage
├── RowControls.qml         a row's typed controls, one Component per entry type (`forType`)
├── UndoPill.qml            "<what> changed · Undo" after every change (Redo after an undo)
├── PageHeader.qml          a hand-written page's action row (the window draws the title)
├── UndoModel.js            pure: undo steps, coalescing, labels (tests/settings-undo.test.cjs)
├── PageCache.js            pure: which pages stay alive (same test)
├── ConfigWrite.js          pure: one dotted key into Config (SettingsStore, PreviewSink)
├── SchemaUtil.js           pure: keys, conditions, inCards / isAdvanced / moreGroups, validation, search
│                           index (node-tested)
├── ResetModel.js           pure: which entries Reset page and the counters touch
├── DisabledReason.js       pure: the failing condition -> reason text / the one switch that fixes it
├── Registry.js             names -> files: EDITORS, PREVIEWS, THUMBS, STAGES, PAGES; DESKTOP_STAGES (the
│                           tabs whose subject is the desktop), PLAIN_STAGES (stages on a plain ground)
├── stages/                 Stage.qml (frame; `calm` = plain card fill, no wallpaper), ScreenMini.qml,
│                           StageSpot.qml; desktop stages Bar, Island, Dock, Desktop,
│                           Lock, Notif, Osd, Windows, Wallpaper; plain stages Power, Updates, Terminal
│                           and the list bands <X>Band.qml (Network, Bluetooth, Sound, Effects, Keys,
│                           Providers, Routines); pure helpers WindowTiles / DesktopPlace / OsdPlace /
│                           KeyDeck.js (node-tested)
├── live/                   LIVE PREVIEWS: the real bar panels / dock / island / toasts / hosted views in a
│                           stage or a picture (LiveTarget, LiveBars, LiveScreen, LivePanel, LiveDock,
│                           LiveIsland, LiveToast, LiveStrips, LiveHosted + HostedFrame; LiveKeys.js,
│                           LivePatch.js, LiveSamples.js)
├── thumbs/                 picture-card thumbs (MiniScreen.qml: the wallpaper screen they draw on)
├── controls/               typed controls (Toggle, Slider, Selector, Number, Text, Font, ColorRole,
│                           List, Path, Screens, Chips, Macro) + ChoiceCard, ChoiceGrid (the one picture
│                           grid, PictureGrid.js), CardSelector
├── editors/                rich `custom` editors (one file each, `property var entry`); PageCard +
│                           CardScroll: a hand-written one-screen page's card and its scrolling body
├── previews/               old under-row previews (`preview`), for pages not converted yet
├── schema/Categories.js    information architecture: destinations, tabs, HOME tiles, MOVED, resolve();
│                           withSections / withEntries / withoutSections / sectionsOf compose tabs
├── schema/<category>.js    one file per category (a tab of a destination)
├── store/SettingsStore.qml get / set (live + undo) / setElsewhere / stageSet (wizard) / reset / focusKeys /
│                           focusOwner / navigate
├── store/UndoHistory.qml   the window's session history (steps, transactions, undo / redo / undoTo)
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
- Home: header (brand, a boxed `SearchField` starting and ending on tile
  edges (`HomeLayout.searchSpan`), a labelled History button with the
  same HistoryMenu as a page header: session changes, All changes), then the nine
  destinations as a bento sized by weight (`Categories.HOME_SIZES`, in
  six-column cells: Screen 4x2, Look 2x2, Panels / Windows / Notifications /
  Devices / Assistant 2x1, Keyboard and System 1x1; `HomeLayout.columns`:
  6, 4 or 2 with hysteresis, spans scale down, the last tile of a line
  takes a hole after it; `Look.screenGap` between them and around), then
  the preset footer. Each tile is a kit `Card` (`interactive`: lifts on
  hover, springs on press, FocusRing; an `Accessible` button with its
  status as description). Screen draws your whole screen as a 16:9 monitor
  (Stage + ScreenMini, every bar, the island and the dock) on its card,
  beside the name and its line (centred on the left) where the tile is
  wide, the parts that are off named too ("dock off"); every other tile
  draws a small live scene of its subject from config / services
  (`Registry.SCENES`, by URL; `tile` is passed in): on a one-row tile the
  scene takes the right part, the icon on a plate (the language's control
  box: hairline ring, tonal box, solid tile, an instrument's well; accent
  tonal on hover / focus) and the name and status the left; on a squarer
  tile the scene stands above the name. A tile without a scene, or too
  small for one (`HomeTile.glyph`), shows its plate. Scenes draw with
  `Mark` / kit pieces only, adapt to their room, and never animate idle. Name = `title` role, status one size down (`secondary`), one
  line that never wraps: its room is there from the first frame, the
  words fade in, trailing " · " parts drop where it is too long
  (`HomeStatus.fit`); in device a lit LED precedes it. Search: typing
  cross-fades the bento into the results (HomeResults: a KeyedListModel,
  rows glide / fade, never rebuilt; breadcrumb + current value; the picked
  row wears the Enter keycap; Enter flashes it and the page grows out of
  it). A scene must not declare a property named like an
  Item anchor line (`top`, `bottom`, `left`, `right`, ...): it hangs the
  type loader.
- Opening (home/MorphFrame): a snapshot of the tile (ShaderEffectSource;
  the real tile is hidden only while it shows) grows from the tile to the
  window (`Motion.morph`) over a card of the language, and the page grows
  with it (scaled to cover the frame, clipped to it) and cross-fades in
  once it is laid out (`SettingsPageHost.pageReady`; `quiet` while the
  morph runs: one fade for the header and the cards). Home is gone in the
  first third. A search result's row grows the same way. A jump to a row
  runs once the morph ended. Back (`Motion.exit`): the page shrinks into
  the tile of the destination shown now (origin taken in `goHome()`, so
  after tabs, Ctrl+Tab, a search or a resize alike) and the snapshot
  takes over. Slow-motion proof: `tools/render/settings_morph_frames.py`.
  A deep link
  (`<app> run settings <id>`, `GlobalStates.settingsCategory` at open)
  opens straight on its page with no motion.
- Destination: `DestinationHeader` = back pill (IconButton), title role,
  the tabs right after the title (`Segmented` with `navigation`: a neutral
  raised pill, `focusable`, Left / Right), then on the right two buttons
  that are always there (the header never reflows): History (the session's
  steps, a click undoes back to one) and ⋯ (Reset page, one undoable step;
  All changes). A tab switch is one transition (`SettingsPageHost`): the
  old page stays until the new one is built, then slides out as the new
  one slides in from the side of its tab (`direction`), glide.
- Page body (SettingsPage): with a content width of 900 px or more, the
  destination grid of two equal columns (`wide`), the same in every tab of
  a destination (switching tabs never changes the content width). With a
  stage (`split`) the right column is the stage, sticky (it scrolls only
  until its foot shows, then stays), with the inspector under it while at
  least 150 px are left (PageInspector), and the cards fill the left one
  in importance order (the `row` lead sections, then the schema order:
  `BentoLayout.order(..., single)`); without one the cards fill both
  columns. A list page (`form: "list"`) keeps its band on top and its
  cards share the band's whole width. After the cards, the tab's folded
  More settings card (PageMore), as wide as the cards' area. The hint
  under the stage shows while the pointer is over it; its line is kept so
  nothing moves. A stage is asked for its height (`preferredHeight`: it
  lays itself out at that height, so the page gives it that, up to the
  view) or is 16:9 (on top: a third of the page at most); stages built as
  page-wide strips have a `narrow` layout (Notifications: the small screen
  over the toast; Menus & OSD: screen and OSD on a line, the menu under
  them; Power: the gauge over the profiles; Island: the state chips under
  the island). The five Screen tabs share `stages/ScreenCanvas.qml`
  (`Registry.SCREEN_PARTS`), one instance kept by SettingsPageHost above
  the pages (`sharedCanvas`; the page reserves its place, `previewAt`):
  the whole screen (bars, island, dock; the tab's part ringed, the whole
  monitor always in frame; a bar picks it, the
  island / dock open their tab, the bar's modules scroll to their card)
  with the tab's own stage as a loupe under it (none for a vertical bar or
  a part that is off), or over it for Widgets & clock and Lock screen;
  each tab's stage is built once and cross-fades. A narrow
  window keeps the stack: stage on top (under the cards, which slide over
  it as it recedes on scroll), a bento (`BentoLayout.js`, 1 to 3 columns,
  starting at the page's left edge) under it. A card (SettingsSection) has a
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
  one line (its tabs take a line of their own, scrolling sideways, when
  they would run under the title or the right-hand buttons).
- Text hierarchy (one scale, sentence case): card title (`title`) > group
  label (kit `group` role: smaller, muted, semibold, more room above than
  below; a stacked row over pictures, an editor, a list or swatches, and
  SectionLabel / Group `role: "group"` in hand-written pages) > row label
  (`body`). The uppercase tracked `label` role is not used in the window.
  The card title, group labels, row labels and pictures share one left
  edge (`Look.rowInset`; a bare editor whose rows draw their own inset
  declares `rowInset: false` and fills the card).
- Rows: label `body`, control flush right (inline) or full width under the
  label (cards, editors, lists, sliders under ~380 px, text fields in a
  narrow card);
  hover / focus = the language's hover box (fades, Motion.micro); a search
  jump = accent wash + focus. The control column (ControlColumn.js): every
  inline segmented (equal segments, `Segmented.segmentWidth`), dropdown,
  slider, field and font picker of a card takes one width, flush right, so
  their left edges line up; switches and steppers keep theirs (steppers of
  a card share one tabular readout width). Two short rows share a line only
  on two shared columns: the odd one after a run of pairs stays in the left
  column (RowLines `half`). Dropdowns and fields in a ghost language (ink)
  are boxes (the raised fill, like Segmented), never underlines; a slider
  of a unitless 0..1 range reads as a percentage; a multiline field
  scrolls inside its box and fades at the cut. A dimmed (CardGate) row
  drains its colour with Motion.micro; a lazy editor fades in.
- Picture cards: `ChoiceCard` - the picture is the card (rounded mask, a
  hairline edge, lifts on hover); selected = the accent ring drawn inside
  the edge (never clipped) + a check badge in the picture's corner + the
  title in the active weight; FocusRing on keyboard focus.
- Inspector (PageInspector, two panes only): the pointed row's name, its
  value now and its default (InspectorLine: name and value wrap), Reset
  while they differ; the description stays the label's tooltip (never
  printed). Moving onto the inspector, or Tab onto its Reset, keeps its
  row (the row's own reset, Tab-reachable, is the keyboard path). With no
  row: "N settings changed on this tab", up to five of them named (a
  composite value says "Changed"), "+N more"; with none changed, the first
  values of the tab. The summary is counted only while it shows, 250 ms
  after the last change (never per frame of a drag, never in a hidden
  kept page). It reads `SettingsStore.focusOwner`.
- More settings (PageMore): a card after the tab's cards whose heading is
  a button (caret, "More settings", how many rows it holds now; Enter /
  Space / click, an `Accessible` button with its expanded state) that
  folds the advanced rows open (Motion.glide) in one group per section
  (SettingsSection `more`: the section title as a group label). Built on
  the first open, kept. Hidden when no advanced row shows.
- Accessibility: a row names its control (`SettingRow.nameControl`: the
  label; `Accessible.description` = the entry's description); direct
  manipulation targets on a stage (corners, edges) are `Accessible` radio
  buttons named by their place; `Type.muted` keeps small text at WCAG AA
  (>= 4.5:1) in light schemes too; the Switch shows the kit FocusRing.
- Stage: `Stage` = wallpaper (palette backdrop without one) in a rounded,
  hair-lined frame, Look.radius("surface"); the miniature on top.
- Undo pill: an opaque popup surface with a shadow at the bottom centre
  (pages keep room for it under their last card), rises in (enter), its
  words cross-fade, stays 5 s (longer while hovered).
Render: `tools/render/settings_render.py --wallpaper assets/wallpapers_example/wallpaper-01.png --palette default
--languages ink,glass,tiles,classic,device [--mode light] [--size 1180x2400] home|PAGE...`
(`home` with `--search Q` shows results, `--hover ENTRY` lights a stage part,
`--undo` shows the pill, `--set KEY=JSON` overrides a config key).
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
About). `HOME` = the destinations in weight order with their sizes (HOME_SIZES); `home()` the
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
  newer one); the History menu names its steps by id too and undoes back
  to one (`undoTo(id)`: it and every newer step, never an older one). A
  key with no entry of its own is named by its parent entry. A step whose
  keys no longer hold its "after" value (something outside the window
  changed them) is dropped, never replayed over the newer value; Ctrl+Z
  then goes on to the step under it. The history is `store/UndoHistory.qml`
  (SettingsStore forwards its API).
- `SettingsStore.setElsewhere(key, value)`: a live change made outside the
  window (the AI panel's model picker, a project's settings): never a step
  of the window's history, so Ctrl+Z in Settings never takes it back.
  The history clears on preset apply / try / keep / revert, on a preset
  edit's save or cancel, on an external reload that changed a value the
  history expects, and when the window closes.
- `SettingsStore.transaction(label, fn)`: every change `fn` makes is ONE step
  (Reset page, a reset of a multi-key entry, a macro slider, an editor that
  rewrites a whole object). Use it in any editor that writes several keys.
- `reset(entry)`, `resetCategory(category)` (Reset page: every row of the
  page, its More card included, `ResetModel.activeItems`): one step each;
  no confirmation (undo instead).
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
  bento synchronously each build frame so no card moves once shown. The
  More card builds no row until it is first opened.
- Heavy live previews become pictures: the lock screen gallery builds one
  LockView at a time, captures it (`grabToImage`) and destroys it; the Lock
  screen stage does the same with the chosen style at stage size (a change
  shows the live view at once, then pictures it again).
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
   Not important enough for the tab's cards? Add `"advanced": true` (a row
   of the tab's More settings card; in the catalog and the CLI as any).
   Most new knobs are.
3. Label / description keys in `translations/{en,es,ru}.json`.
4. `make schema` (catalog `assets/schema/*.schema.json`).

Entry fields: `key` (dotted, `domain.prop[.sub]`), `type` (`toggle | selector
| slider | number | text | font | color-role | list | path | screens |
multiselect | macro | custom`), `label`, `description` (tooltip + catalog),
`hint` (i18n key: the one visible caption line, rare), `keywords`,
`advanced` (a row of the More card, not of the cards), `placeholder`, `pattern`, `options`
(`[{value, label, icon}]`), `display: "cards"` + `thumb` (picture cards),
`min/max/step/unit`, `specialValues`, `visibleWhen` / `enabledWhen`
(declarative: `{key, equals|notEquals|in|truthy|empty}`, `{key, some: {field,
in|notIn}}`, `{all|any: [...]}`, `{not: ...}`), `reason` (why an
`enabledWhen` row waits when no single switch decides it), `preview` (old
under-row preview, unconverted pages only), `component` (custom editor),
`keys` (every key a composite entry reads / resets), `sizeKey` / `sizeUnit`
(font), `resettable: false`, `compositor`, `id`, `target` (PageLink),
`invert` (a toggle shown on for false), `multiline` (a text row of prose:
a wrapping box of a few lines, commits on focus loss or Ctrl+Enter), `surface` (a host picker's surface
id: the row notes "Island is off - shown as X"; the stage draws it).
`lazy: true` (a heavy custom editor in a card of the page row: compiled and
built on the frame after the page shows, asynchronously; the card height is
fixed, so nothing moves). `part: true` (an editor of one part of a composite value that another entry
also edits, e.g. the bars list beside the stage and the selected bar's
fields; exempt from the one-control check).
Section fields: `id`, `title`, `entries`, `toggle` (the key of a switch of
the section drawn in the card's heading, for a card that is the thing it
turns on: Special workspaces), `advanced: true` (the whole section
is a group of the More card), `compositor`, `span`. A section shows only while one
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
A page: the header (DestinationHeader, outside the scroll: always
visible, History and ⋯ included), then the scrolling page (SettingsPage,
see LOOK > Page body). Wide (content 900 px or more): two equal columns,
the cards (PageBento) in the left one and the stage sticky in the right
one with the inspector under it, or, without a stage, the cards in both.
Narrow, or a list page: the stage (a list page's band) on top and the
cards under it. Last, the tab's folded More settings card (its advanced
rows). Nothing hides in a sheet; the page scrolls.

- Previews are the thing itself, big and readable, never a shrunk desktop
  where the desktop is not the subject. Strip stages (`pageWide: true`,
  `preferredHeight`): the Bar (the real panel picked for editing, live/LiveBars,
  laid out on a screen as wide as the page at up to its true size; a click
  on a module scrolls to and flashes its card), the Island
  (drawn big in its shape, a state picked with chips: at rest, music,
  notification, timer), the Dock (the real dock, live/LiveDock), and on a plain ground the Launcher, the Dashboard, the Chat,
  a notification (a toast at its real size, grouped, from the island or
  as a strip; with corner toasts a small screen whose corners move them)
  and the real OSD beside a bar menu in the popup style (a small screen
  whose edges move the OSD). Where a thing sits is its Edge row, not the hero. Every StageSpot
  flashes briefly when one of its keys changes. settings-fit wants the
  smallest glyph on the bar, island and dock strips at 10 px or more.
- Picture cards: one pattern (controls/ChoiceGrid.qml + PictureGrid.js,
  also used by the picture editors and PickTile): compact (about 96 to
  150 px), the rows balanced (5 on one line, 6 -> 3 + 3, 7 -> 4 + 3, never
  an orphan; a short last row centred), every row filled to the card's
  edge (a very short row stops at 1.4x the cap), every card of a grid as
  tall as the tallest; a single choice between named things (a key combo,
  a resolution) is a Segmented or a Dropdown, never chips. The object
  drawn on a plain ground (thumbs/MiniScreen `desktop: false`,
  thumbs/ThumbGround); the wallpaper only where it is the subject (fit,
  transition) and in real captures (lock styles, presets). Names wrap to
  two lines, the chosen one ringed inside its edge, with a check badge; a compact
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
  width. On a page of three columns a narrow card fills a free top slot
  before any card goes under another; a card with a free column beside it
  on its line takes that column too (a band always uses the whole width);
  the last card of a column stretches down to the tallest column when the
  column beside it ends short too (no ragged blank two columns wide). A
  desktop stage on a page of three columns stands in the first column, the
  cards beside and under it (`SettingsPage.beside`, a reserved block of
  `place`). Inside a card, picture choices that follow each other share
  one line when their pictures fit it (RowLines.js: Wallpaper's two fits
  beside its six transitions). The layout probe fails on an empty column
  (three or more cards), a column ending more than about a card above the
  tallest while cards remain below the fold, and a blank wider than one
  column and over 120 px tall inside the first screen's content.
- One thing once: no card holds a single plain row (Categories.mergeInto
  folds it into the card it belongs with; moveEntry puts a feature's switch
  at the head of its card), a card header shows no value summary (the
  card's control shows it), a row is never named like its card, labels are
  in sentence case (tests/settings-page-unique.test.cjs). Translated text
  wraps, never elides; only data (file, network, model names) may. settings-fit counts the whole rows on the
  first screen (8 with a stage, 9 without: one column); the tabs still short of it are
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
  `hero.foot`: a strip along the stage's foot (Wallpaper's library); on a
  wide page it stands beside the miniature as a grid as tall as it
  (`SettingsPage.footSide`).
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
- Motion: a card folding rows open or shut moves the cards under it in
  the same frame (lockstep, no gap, no snap); a discrete relayout (a card
  shown or hidden, a new column count) glides x, y and width; a resize
  never animates. Geometry that follows a container (PartChip,
  ScreenMini's windows, the island stage) uses RectGlide, never a bare
  Behavior.
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
Direct manipulation: dashed zones (kit `DashedFrame`) for places (the
Widgets & clock stage offers "Move here" on the side the clock does not
use, where its style can go: DesktopPlace.js), `partsClickable` for the island / dock; write through
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
   not, `"advanced": true` (or the whole section: the More card). Plumbing
   never stays in the cards:
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
   (thumbs/<Name>.qml with `property var entry`, `property var value`, on
   `MiniScreen`; a look of a shell part is the real part with the option
   as an override (LIVE PREVIEWS: LivePanel / LiveDock / LivePart), only
   abstract choices are drawn with `Mark` / `StyledRect` / `KitText`;
   register it in `Registry.THUMBS`). Options of a registry (styles, numerals) ->
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
   An edge choice is its row of picture cards (the stage is a strip); a
   corner / place choice gets ghost targets like NotifStage (hover shows the thing there,
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

## LIVE PREVIEWS
A stage or a picture card of a shell part shows THE part: the shell's own
component, created by URL, at its native size, scaled down, never a
drawing of it. So a new bar module, panel style, indicator style, numeral
system, clock face or dock style shows up in Settings with no settings-side
code, and the preview cannot drift from the shell.

Pieces (foundation: `modules/components/preview/`, importable by any part):
- `PreviewContext` (QtObject): handed to a part's root as `preview` (null in
  the live shell). `overrides`: `{"dotted.key": value}` shown instead of the
  live config; `samples`: `{"part.key": value}`, data a part shows instead
  of a live service or its runtime state (a launcher query, the dashboard's
  tab, a conversation, the island's track / notifications / activities;
  each key is documented where the part reads it). A part with a context
  is revealed at once (no auto-hide, no hover reveal) and claims nothing
  session-wide.
- `Preview.js`: `pick(ctx, key, live)` (the override, else the live value,
  read in the caller's binding so it keeps following the config),
  `sample(ctx, key, live)` (the sample, else the service's value; a null or
  empty sample is "none" and wins), `on(ctx)`, `withValue(overrides, key,
  value)`.
- `LivePart`: the generic host. `source` (URL), `properties` (initial, the
  required ones too), `nativeWidth/Height` (or the implicit size), `crop`
  or `cropOf(item)` (the native rect framed, measured once settled and then
  bound), `fit` / `zoom` / `maxZoom`; inert (`interactive: false`: no pointer,
  hover or keys, so its popups never open); `active` (a hidden page builds
  nothing); `snapshot` (built, pictured with grabToImage, destroyed: a
  gallery holds pictures, not objects) + `refreshKey` (a change pictures it
  again); `mapFromPart(item, rect)` for a page's own overlays; `settleMs`
  (time to settle before it is measured / pictured; a part whose root has
  a `ready` property is waited for until it is true). Readable:
  `minZoom` and `readableGlyph` (the zoom that draws its smallest text,
  measured once settled, at that many px; both under `maxZoom`); when that
  no longer fits, `cut` says what shows: "center", "start", or "ends" (a
  long thing, twice as long as it is deep, shows its start and its end
  side by side with a small break: the second view is a ShaderEffectSource
  of the same part, no second instance). Built through
  `LiveGate`, asynchronously. Torn down, its frame stops following the
  part (`leaving`: an owner's `cropOf` never runs in a dying context).
- `LiveGate` (singleton): the build queue. A page shows first (no live part
  is created in the frames that lay it out: opening Bar costs ~40 ms, as
  before), then its parts are built one per frame (`ask(owner, build)`,
  `forget(owner)` on destruction). Tests and renders that look at a stage
  wait for it: `live_previews.wait_built(env)` (settings_render does).
  Until its panels exist LiveBars reports the configured depth
  (PanelLayout.estimateDepth), so nothing moves when they arrive.

Settings side (`modules/settings/live/`):
- `LiveTarget` (singleton): the screen previews are laid out on (the
  focused one, else the first); its logical size is the native size of a
  picture of one part. `overviewWidth/Height` / `overview`: the screen
  whole-screen miniatures (ScreenMini: the canvas, the home tile, the
  desktop / wallpaper / windows stages) lay the real parts out on: your
  screen's shape, at most 1280 px wide (`overviewMax`). Why: on a 2560 or
  3840 px monitor a whole screen at true proportion in a ~550 px canvas
  draws a 44 px rail 9 px wide (the owner's "hairline with dots"); on the
  overview screen the parts keep their real pixel sizes and only the empty
  space between them shrinks, so they read (a module ~16 px in the canvas).
- `LiveBars`: every bar panel of a bar config (`bar`, default the live
  `Config.bar`; `only: index`) as real BarContents with a context.
  Geometry in native px: `bars`, `depth(edge)`, `panelRect(i)`, `modules()`
  (every module slot, found by its objectName `barSlot:<id>`, set by
  BarModuleSlot for any module of the registry).
- `LiveScreen`: LiveBars + the real dock (DockContent) + the real island at
  rest (shell/NotchPreview, LiveSamples' "rest") at the screen's size;
  ScreenMini scales it (`k`) and draws the windows, frame, corners (the
  real ScreenCornersContent) and the page's interaction (panel rings /
  picking, module buttons, the island's / dock's spot, ring and click, and
  StageSpots from `panelRects` / `moduleRects` / `islandRect()`, re-measured
  after each change and when the pointer arrives).
- `LivePanel`: one real panel in a picture: your primary panel's spec with
  `patch` over it (`LivePatch.only(ids)`, `sample(groups)`, `style(id)`),
  `overrides`, `frame: "panel" | "modules" | "edge"` ("edge": the screen's
  band along the panel's edge, from the edge to past the panel, to the
  screen's corners or around the modules when the panel stands apart: the
  bar Shape cards, laid out on your real screen size with `cut: "ends"`:
  both corners, the gap, the radius, the islands, the first and last
  modules), `snapshot`, `refreshKey`. Readable by default
  (`readableGlyph: 10`, `cut: "ends"`).
- `LiveDock`: the real dock framed on its surface (`overrides`, e.g.
  `dock.theme`, `dock.iconSize`, `dock.indicator`), `surfaceRect` in the
  item; `frame: "app"` frames one running app (the indicator cards), `zoom`
  one scale for several (the size cards).
- `LiveIsland`: the real island (shell/NotchPreview.qml: the Notch, the
  resting view, its place on the edge) showing `state` ("rest" | "media" |
  "notification" | "timer") from LiveSamples; `overrides` (`notch.style`,
  `notch.position`, `notch.align`); framed as a window of the item's size at
  `zoom` on the island's edge, centred on it (the island hangs from the
  item's edge as from the screen's), or `frame: "screen"`; `targetRect`
  (native, not animated: size a stage once per state, the island morphs
  into it), `islandRect` (in the item); `frame: "island"`: the island and
  its band from the edge, readable (`readableGlyph`, `cut`: the shape cards).
  Island stage, shape / edge cards,
  the Notifications stage's island.
- `LiveToast`: the real corner toast (notifications/CornerToast.qml) with
  the sample message, `grouped` (the app's stack behind it), `stackUp`, at
  the shell's width (ToastModel.toastWidth); `snapshot`.
- `LiveStrips`: the real strips (notifications/strips/StripsView.qml) with
  the sample groups, framed on their hit box.
- `LiveSamples.js` (pure): the content previews show: the island's
  `STATES` (id, label, card), `island(state, now, art, timerActivity)`,
  `track(art)`, `messages` / `group` / `groups(now, grouped)`, `timer(now)`
  (made an activity by the shell's TimerActivity.timerActivity, so its
  label and ring follow `system.timers`), `osd()`.
- `LiveKeys.js`: a module's StageSpot keys and the Bar card it opens
  (generic default: `bar.moduleOptions.<id>` / the layout card).
- `LiveHosted`: a hosted surface as it opens: the shell's own view (`source`
  by URL, `properties`, `overrides`, `samples`) inside its host's own frame
  (`HostedFrame`: the notch's NotchSilhouette, the spotlight / sheet
  HostFrame, both by URL; "sidebar": a view that is its own surface), where
  the host puts it (`host`, default HostResolve of `surface`: the notch
  hangs from its edge, the spotlight is centred, the sheet / sidebar stand
  on their `side`). Scaled to fit up to `maxZoom`; below `minZoom` it stays
  readable and the item's edge cuts it (the sidebar shows its end).
  `cutSides`: below `minZoom` its side edges may cut it too (the result
  style cards: the launcher's top-left corner, its search and first
  results, at a size where they read).
  `snapshot` / `refreshKey` / `settleMs` as LivePart; `ready`, `view`,
  `frameRect`, `find(objectName)`, `mapFromView(item)` for overlays. The
  view stays enabled (a disabled kit row reads greyed out) and a cover
  takes the pointer (the wheel scrolls the page). Not built while hidden.
- `stages/ViewSpot`: a StageSpot over a named child of a LiveHosted view,
  measured again after a change.

Making a part previewable (shell side, the smallest seam): give its root
`property var preview: null`; where it reveals, auto-hides or claims a
session-wide thing (IPC targets, owners, edge reservations, weather covers)
skip that when `Preview.on(preview)`; pass the context down where children
read it (bar modules get it as `bar.preview`; Workspaces passes its looks to
its buttons); read each look key a picture may vary through `Preview.pick`.
A state of a part comes from samples, never from the session: read the
service through `Preview.sample(preview, "name", Service.value)` where the
part decides what it shows (the island: `player`, `notifications`,
`activities`, `levels`, `focusedTitle`; the strips: `popupGroups`,
`popupAppNames`; the bar's inline OSD: `osd`), and in a preview drop what
would animate or register (the visualizer draws the sample `levels` still
and never asks cava; the inline OSD registers no host and takes no OSD
event; the island's notification is born at once).
Overridable today: `workspaces.indicatorStyle`, `numeralStyle`,
`showNumbers`, `alwaysShowNumbers`, `showAppIcons`,
`bar.moduleOptions.clock.face`, `dock.theme`, `dock.enabled` (integrated
dock in a bar), `dock.iconSize`, `dock.showRunningIndicators`,
`dock.indicator`, `notch.style`, `notch.position`, `notch.align` (the
island: Notch, NotchSilhouette via Notch, DefaultView, IslandHeader,
IslandNotifications, NotchPreview); a panel's style / groups / edge are its
spec (LivePanel `patch`), no override needed. Also
`layout.launcher.resultStyle` / `.preview` / `.compactWhenEmpty`
(LauncherView, LauncherSearch), `layout.dashboard.home` (Dashboard).
Samples read today: `launcher.query`, `launcher.selected`, `launcher.live`
(providers created and searched for real: the apps, in memory),
`launcher.rows` (`{providerId: [rows]}` of the others; LauncherSamples.js);
`dashboard.tab` (a stable tab index); the Assistant panel's `ai.rows`,
`ai.model`, `ai.effortLevels`, `ai.effort`, `ai.cost`, `ai.context`,
`ai.limit` (modules/aicenter/AiCenterPreview.qml).
Hosted views: the launcher (LauncherView: the search tab only, no focus,
no GlobalStates writes, nothing runs) and the dashboard (Dashboard: your
live widgets, the sample tab; no popups hidden, no tab shortcuts) take
`preview` at their root. The Assistant's panel (AiCenterPanel) is wired to
the Ai service throughout, so AiCenterPreview composes its surface from
the same parts (CenterHeader, TranscriptView, ComposerStatus + EffortChip,
Composer), which take `preview` and then never read Ai; keep its column in
step with AiCenterPanel's.
Showing a part in a stage: a LivePart (or LiveBars / LiveDock / LivePanel)
in the stage, interaction drawn on top from mapped rects. A picture card:
the thumb renders the part with its option as an override; galleries of
the OSD and island styles use `snapshot` with a `refreshKey` of what they
show. The bar Shape and dock style cards stay live: their snapshots came
out blank offscreen for some styles (grabToImage of a just-rebuilt panel;
investigate before using `snapshot` for panels).
Readable, whatever the monitor (the owner's is 2560 px wide): a picture is
never the whole part shrunk to the card; it frames what tells the options
apart at a zoom where the text reads (`readableGlyph`), cutting the rest
(`cut`), and a whole-screen miniature uses the overview screen. A new card:
give its Live* `readableGlyph: 10` and the `cut` that keeps the telling
part. The stages' wallpaper is the picture itself
(`SettingsStore.wallpaperSharp`: not the small thumbnail the window's
ambient uses), decoded at the stage's size in device pixels.
Why live parts and not a look object threaded through every component:
the shell reads its config in many places; only the keys a picture varies
need a seam, and a preview of the current value needs none (the part reads
the live config, so every other setting follows by itself). Why pictures
for galleries: whole parts stay objects otherwise; strips (workspaces,
clock) are small and stay live (they follow the workspaces too).
The Bar stage (BarStage) lays the picked panel out on a screen as wide as
the stage at up to its true size (`laneWidth`, taken after layout: the page
sizes stages from their height), measured once at the real width after each
change (`need`: its groups' natural length): wider bars are shown smaller.
Test env: `tests/lib/live_previews.py` merges panels_env's import tree and
fixture desktop into SettingsEnv (one 2560x1440 screen, or
`YOZAKURA_TEST_SCREEN=WxH`; `settings_render.py --screen 3840x2160`), so every settings
test and render shows the real bar (it also leaves through
`clean_exit`: the live modules crash PySide's teardown pass), plus the
island's and the notifications' trees with idle services (a stage's samples
are what it shows). `tests/settings-live-legible.test.py` (at 2560x1440
and 3840x2160): every readable part's smallest text >= 10 px in the window
(8 at its maxZoom cap, 6 for a hosted window's corner), the canvas on the
overview screen with modules ~16 px tall. `tests/settings-live-parts.test.py` checks the island
states, the canvas island, the three notification presentations, the inline
OSD and a dock indicator override, and that no preview registers anything.
Render a state: `settings_render.py notch --eval 'islandStage:showing =
"media"'` (`--eval` runs on every item of that name).
The island: NotchContent is the live notch's composer (Visibilities, hover,
avoidance, registrations); a preview uses `shell/NotchPreview.qml` instead
(shell layer, beside it: the same Notch and DefaultView, placed with
NotchPlacement and `NotchShape.edgeGap` like NotchContent, EdgeService's
environment with the preview's place), so nothing of the session runs.
The Island stage shows each state with the island's own morph (its height
follows `targetRect`); the canvas shows it at rest; the shape cards
(one scale for every shape) and edge cards picture it with the option as an
override.
Notifications: the stage is the real corner toast (LiveToast), the real
island holding the sample message (LiveIsland "notification": its card or
compact style is the live `notifications.notchStyle`) or the real strips
(LiveStrips); the corner cards picture the real toast at each corner.
Menus & OSD: the OSD styles are their real components (LivePart, sample
`osd()`), "in the bar" your bar's real controls button holding the level
(LivePanel with the `osd` sample); the menu is the shell's popup surface
(components/PopupSurface.qml, shared with BarPopup: the popup style, entry
motion, replayed when `theme.popup.entry` changes, and tail) holding the
bar's menu rows (bar/modules/MenuRow.qml, by URL) with sample actions.
Dock: the size cards are your dock at each `dock.iconSize`, one scale for
all; the indicator cards your dock framed on a running app with each
indicator (DockIndicator picks `dock.indicator`).
Live: the Launcher stage and result-style cards (LiveHosted, LauncherView),
the Dashboard stage and home cards (LiveHosted, Dashboard; the cards are
snapshots), the Assistant stage (LiveHosted "sidebar", AiCenterPreview).
Test env: live_previews also mirrors the launcher, the dashboard's stage /
home / widgets and the AI center's transcript / composer / header trees
(`HOSTED_QMLDIRS`, stand-in Metrics / Wallpapers tabs and launcher prefix
tabs) with idle service stand-ins; app icons are PNG files (an
asynchronous `image://icon` from the Python provider deadlocks).
Still drawn: the windows and frame of the canvas (no shell part), the small
screens with corner / edge targets of the Notifications and OSD stages
(controls, not parts); the Windows stage and the Overview style cards (the
overview and tiling show live compositor windows and screencopies: they
need sample windows in a PreviewContext); the Assistant's message-style
and size cards (BarLook, a singleton, reads the message style: an override
cannot reach it; the size card is the panel's share of the screen, a
placement diagram). Power, Updates and Terminal are settings views
(Terminal already shows the real TerminalPreview).

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
  coordinates; read-only geometry `unit` (a readable overlay unit, not the
  scale), `k` (native px -> stage px), `freeRect`, `islandRect`,
  `islandEdge`, `depths`, `edgeDepth(edge)`, `panels`, `panelRects`,
  `moduleRects`. Its bars and dock are the real ones (live/LiveScreen).
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
The home search (Ctrl+F from a page too) covers every row of the window,
the More cards' too (`SchemaUtil.buildSearchIndex`: every labelled entry,
`advanced` marked; an equal match ranks a card row first); typing
anywhere on home starts it. A result names its destination (and tab,
"More settings" for an advanced row, section) and shows the row's current
value; Up / Down pick, Enter opens the highlighted one, Esc clears, Down
in an empty field goes to the tiles. It lands on the row (scroll, accent
wash, keyboard focus); an advanced row's jump opens the More card first
(PageMore.rowFor, at once, no fold animation). `Synonyms.js` (en + ru)
maps words people type to the words the schema uses. The Changes tab
lists every shown setting that differs from its default or the preset,
each with a jump to its row (a More card row too; ResetModel.changedItems
lists a More entry whose keys a card row holds once, by that row).

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
  `settings-displays-flow` (`.test.py`), `settings-strip.test.cjs`,
  `live-preview.test.cjs` (Preview.js, LiveKeys.js, LivePatch.js),
  `settings-launcher-samples.test.cjs` (LauncherSamples.js).
- Separate process: `tests/separate-windows.test.py`, `tests/preview-staging.test.py`
  (the wizard's relay), `tests/window-entries.test.py`, `tests/onboarding-*.test.py`.
- Tests that open the whole shell end with `h.exit(...)`: kept-alive pages
  must not outlive the singletons at interpreter teardown.

