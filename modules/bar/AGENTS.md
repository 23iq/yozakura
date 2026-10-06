# BAR MODULE KNOWLEDGE BASE

## OVERVIEW
Primary system panel supporting horizontal (top/bottom) and vertical (left/right) orientations, reactive auto-hiding, and space reservation via Quickshell's `PanelWindow`. Rendered inside `UnifiedShellPanel`.

## STRUCTURE
- **Panels engine** (`panels/`): the bar is a set of *panels* (`bar.panels`), each `{id, edge, style, groups{start,center,end,drawer,gapStart,gapEnd}, align, size, thickness, margin, flat, autohide auto|always|never, reserve, screens, enabled, options}`. An empty list is the legacy single bar (`bar.position` + `bar.layout` + `bar.screenList`), rendered pixel-identical to before.
  - `panels/PanelLayout.js`: pure engine (normalize + warnings, legacy migration, screen filter incl. `primary`/`secondary`, primary panel = the one on the notch edge, per-edge reservation math, serialize). Tests: `tests/panel-layout.test.cjs`.
  - `panels/PanelStyles.js`: **style registry** (file, edges, groups, flat, module size, containable, activity mode, floating). Adding a style = one `panels/styles/<Name>Panel.qml` + one entry + label translations.
  - `panels/Panels.qml` (singleton): resolved panels, `forScreen()`, `primaryEdge` (use it instead of `Config.bar.position`), the shared pin toggle (SUPER+SHIFT+B flips `bar.pinnedOnStartup` once).
  - `panels/PanelStyleBase.qml`: contract of a style (implicitThickness/Length, outerMargin, sideMargin, padding, start/endReach, fillet).
  - `panels/styles/`: `ClassicPanel` (+ `FloatingPanel`), `IslandsPanel` (+ `CornersPanel`), `PillsPanel` (`BarPill` per group), `PanelStrip` (+ `MenubarPanel`, `StatuslinePanel`, `RibbonPanel`, `RailPanel`), `DockPanel` (+ `DockLikePanel`); style `none` has no file (`hidden`: the panel is disabled, no window, no reservation). `PanelStyles.barStyles()` = the `bar.layout.style` looks (full=classic, floating, islands, pills, dock-like, none), tested by `tests/bar-styles.test.{cjs,py}`; shared `PanelCenterGroup`, `PanelGapSlots` (flat modules in the free spans next to the center/notch). Loaded by URL from BarContent; `panels/` must never import `qs.modules.bar` (no import cycles).
  - `PanelHost.qml`: one BarContent per panel of a screen; exposes `primary`, `zones` (exclusive zone per edge, fed to `shell/ReservationWindows`), `containSides` (frame growth for `containBar`), `hitRegions` (input mask).
- **Core Layout**:
  - `BarContent.qml`: one panel — auto-hide (`reveal`, `hideDelayTimer`), hover hitbox, edge placement (fill or aligned span), module groups, drawer; the look is the style component. Modules get it as `bar`/`barRoot` (`moduleSize`, `flat`, `panelStyle`, `options`).
  - `BarLayout.js`: legacy `bar.layout` helpers (normalize, default arrangement, pill radii, separators). Unit tested in `tests/bar-layout.test.cjs`.
  - `BarModuleRegistry.js`: **module registry** (id, icon, label, `file`). Built-in modules are hand-wired in `BarModuleSlot.qml`; file modules live in `modules/` and share `modules/BarModuleBase.qml` + `BarModuleSurface.qml` (flat-aware pill). Adding a module = one file + one entry + translations.
  - `BarModuleSlot.qml` / `BarModuleGroup.qml`: id -> component (Loader forwarding `Layout.*` hints, module size and flat mode) and the Repeater placing a group (optional separators).
  - `BarDrawer.qml`: drawer modules, revealed next to the end group on hover (notch hover delays/timing).
  - `BarIsland.qml` / `IslandShape.qml`: notch-like tab and silhouette, mapped onto any edge.
  - `BarBg.qml`: strip background (variant `barbg`, or `bg` via panel `options.surface`).
  - Sizes: `modules/theme/BarMetrics.qml` is the single source of resting sizes; panels may override the module size (`size`, style default). `BarMetrics.iconFor(base, size)` scales glyphs.
- **New modules** (`modules/`): `WindowTitle`, `AppMenu` (window actions + move to workspace), `Taskbar`/`TaskbarButton` (pinned + running; on dock panels: dots, `dock.magnification`, `dock.launchBounce`), `SystemStats` (CPU/RAM/GPU/temps/net, keeps `SystemResources` sampling while shown), `WeatherChip`, `WorldClocks`, `WorkspaceTags` ([1][2][3]), `KeyboardLayoutIndicator` (EN/RU; click = next layout, wheel cycles; hidden unless >1 layout and `keyboard.showIndicator`), `DownloadsStack` + `DownloadsFan`, `WorkspacePreviews`. Options in `bar.moduleOptions.<module>`; pure helpers tested in `tests/panel-modules.test.cjs`.
- **Rendering**: `tools/render/panels_render.py LAYOUT.json...` renders whole-screen layouts headless (dark/light, contact sheet); `tests/panels.test.py` covers reservations, autohide, screens and every style on every edge.
- **Live activities** (`activities/`): islands next to the notch fed by `ActivityService`.
  - `ActivityHost.qml` (mounted in UnifiedShellPanel): reads bar extents (`BarContent.startExtent/endExtent/islandFillet`) and the notch rect; Loader active only while activities exist.
  - `ActivityLayout.js` (pure, tested): placement mode — `tab` (notch-shaped tab from the edge: islands bar on the notch edge, or bar on another edge), `pill` (classic bar on the notch edge), `floating` (notch theme "island"); privacy prefers the right side, tasks the left, spill-over, then "+N".
  - `ActivityGaps.qml` (layout + retract-aware delegates), `ActivityIsland.qml` (body per mode, grow/retract), `ActivityContent/Indicator/Ring.qml`.
- **Widgets**:
  - `clock/`: Time, date, weather integration (`Clock.qml` — 672 lines).
  - `systray/`: SNI-based system tray.
  - `workspaces/`: Compositor workspace visualization and navigation. `Workspaces.qml` lays out `WorkspaceButton` slots (layer visibility in `WorkspaceSlot.js`); `WorkspaceNumberLabel` renders the number in `workspaces.numeralStyle`. Numeral systems live in the `WorkspaceNumerals.js` registry (format, auto font, optical fit hints); add an entry there to add a system (settings, validation and the font probe in `services/NumeralFonts.qml` pick it up). The active slot is marked by `ActiveIndicator.qml` (stretchy two-index box) in `workspaces.indicatorStyle`: one QML per style in `workspaces/indicators/` + an entry in the `IndicatorStyles.js` registry (pill, underline, dot, brush, bracket). Tests: `tests/workspace-numerals.test.*`, `tests/workspace-slot.test.cjs`, `tests/workspace-indicators.test.py`, `tests/surface-effects.test.cjs`.
  - `IntegratedDock.qml`: Taskbar-style dock embedded directly into bar layout.
- **System Indicators**: Volume, brightness, battery, power profile sliders/buttons.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Auto-hide logic** | `BarContent.qml` | `reveal` property + `hideDelayTimer` |
| **Space reservation** | `PanelHost.zones` → `shell/ReservationWindows` | per edge, deepest reserving panel |
| **Adding widgets** | `modules/<Name>.qml` + `BarModuleRegistry.js` | file module on `BarModuleBase`; place it via `bar.panels[].groups` |
| **Adding a panel style** | `panels/styles/<Name>Panel.qml` + `panels/PanelStyles.js` | implement `PanelStyleBase` |
| **Integrated dock** | `IntegratedDock.qml` | App switching within bar |
| **Clock/Weather** | `clock/Clock.qml` | Complex: 672 lines, multiple display modes |

## CONVENTIONS
- **Adaptive styling**: Widgets use `startRadius`/`endRadius` for "pill" continuity based on group position.
- **Visibility registration**: Panels must register with `Visibilities` in `Component.onCompleted`.
- **Orientation**: ALWAYS handle both `horizontal` and `vertical` cases in UI components.
- **Config binding**: Use `Config.bar.*` properties for all layout-related state.
- **Screen filtering**: each panel's `screens` (names, `primary`, `secondary`); the legacy bar uses `Config.bar.screenList`.
- **Bar edge**: read `Panels.primaryEdge` (or the panel's `barPosition`), never `Config.bar.position` directly.
