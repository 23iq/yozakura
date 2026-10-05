# Desktop Module

## OVERVIEW
Desktop background layer with icon grid, supporting drag-and-drop reordering, thumbnails, and file operations via DesktopService.

## STRUCTURE
- `Desktop.qml` — PanelWindow with icon grid. Uses WlrLayershell Bottom layer. Grid computed from `iconSize` + `spacingVertical`.
- `DepthClock.qml` — thin host for the depth clock, drawn *inside the wallpaper surface* (loaded from `WallpaperImage.qml`): wallpaper → style "behind" part → subject cutout (`DepthMaskService`, edges sharpened in `shaders/depth_cutout.frag`) → style "front" part. Config: `desktop.depthClock`, `desktop.depthClockStyle` (registry id), `desktop.depthClockPosition` (`auto`/`left`/`right`), `desktop.depthClockVideo`. Interface used by `WallpaperImage.qml` (keep it): in `wallpaperPath`, `isVideo`, `matteActive`, `tint`, `suppressed`, `frontHost` (item above the video matte subject; the front part is moved there); out `canDepth`, `depthActive`.
- `clockstyles/` — clock styles. `ClockStyleRegistry.js`: id → QML file, label, icon, `needsDepth`, `sides`, `layout(ctx)` (geometry shared by the QML and by placement). `ClockStyle.qml` is the base interface (`part`, `now`, `light`, `side`, `layout`, `use12h`, `animDuration`; ink roles). `ClockPlacement.js` scores each style's boxes against the grid from `scripts/depth_mask.py` (coverage, loop-wide worst case + jitter for videos, luminance) — depth only if every `legible` box stays ≤30 % covered. `ClockText.js`: kanji date/weekday/meridiem. Shared bits: `CssLine` (CSS line-height), `VerticalText` (upright vertical CJK), `ClockHalo`.
  - **Add a style**: one `clockstyles/<Name>Clock.qml` extending `ClockStyle` (show only the items of its `part`) + one entry in `ClockStyleRegistry.styles` (+ a `labelKey` translation). Use only fixed colour roles (`ink`, `inkSoft`, `accent`, `halo`) so it works on every preset and in light/dark schemes.
  - Fonts live in `assets/fonts/clock/` (OFL, licences next to them) and load via `FontLoader`. Shippori Mincho is subset: `pyftsubset ShipporiMinchoB1-<W>.ttf --text="0123456789時分一二三四五六七八九十〇月日曜火水木金土夜桜午前後" --unicodes=U+0020-007E --layout-features='' --no-hinting --desubroutinize`; League Gothic / Space Grotesk ship unmodified (Reserved Font Names forbid modified copies).
- `ClockBackdropProbe.qml` — luminance-only placement grid measured with a `Canvas` when the mask script has no data (no venv), so the ink still matches the backdrop.
- Video wallpapers: `scripts/depth_video.py` builds a stacked colour+mask "matte video" per video (`DepthMaskService` background job). `WallpaperImage.qml` then plays it via `VideoWallpaper` (matte mode, `depth_matte.frag`) and draws the moving subject above the clock with `DepthMatteForeground` (both in `modules/widgets/dashboard/wallpapers/`). No matte / disabled / broken matte → plain video, clock in front.
- `widgets/` — desktop widgets, drawn by `Desktop.qml` (the desktop window exists when icons are on or `DesktopWidgets.wanted`).
  - `WidgetRegistry.js`: type id → file in `types/`, label/desc keys, icon, default/min size (px at 1440p), generic options. **Add a widget** = one `types/<Name>Widget.qml` extending `DesktopWidget.qml` + one registry entry (+ translations). A type uses `options`, `ink` (surface item colour), `k` (scale) and only polls while `active`.
  - Config `desktop.widgets`: `[{id, type, monitor, x, y, w, h, options}]`, x/y/w/h fractions of the screen; unknown monitor → first screen. Normalized by the registry; `desktop.widgetGrid` snap, `desktop.widgetVariant` StyledRect variant (glass surface `widgets`), `desktop.widgetsEnabled`.
  - `DesktopWidgets.qml` (singleton): normalized list, `editMode`, `clockAreas` (published by `DepthClock.areaKey`), pure list builders (`withAdded/withUpdated/withOption/withRemoved`) + `commit()`.
  - `DesktopWidgetsCanvas.qml` → `WidgetFrame.qml` per widget (stable `WidgetIdModel`, so editing one never recreates the others); edit mode: `EditBackdrop` (scrim, grid dots, clock area), `EditToolbar`, drag/resize/remove, overlap warning. `WidgetGeometry.js`: snapping, clamping, free spot, window coverage (covered widgets are hidden and inactive). Edit mode: settings button, desktop right-click, `yozakura run desktop-edit` (bindable action), Esc/Done to leave; the layer moves to Top while editing.
  - Helpers: `CalendarModel.js` + `CalendarEvents.qml` (khal), `NetRate.js` (/proc/net/dev), `Sparkline.qml`, `WidgetButton.qml`.
  - Renders: `tools/render/desktop_widgets_render.py [--settings]`.
- Depth clock ink: `desktop.depthClockInk` (`auto` or a role in `ClockStyleRegistry.INKS`), passed to styles as `inkRole`.
- `DesktopIcon.qml` — Individual icon delegate. Handles click/double-click, context menu, thumbnail loading.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Icon positioning | Desktop.qml:48-51 | Grid cell dimensions from `Config.desktop.iconSize` |
| Drag-and-drop | Desktop.qml:146-183 | DragHandler + DropArea with index calculation |
| Thumbnail logic | DesktopIcon.qml:20-48 | FileView watches thumbnail path; triggers refresh |
| Icon rendering | DesktopIcon.qml:137-208 | Normal vs tinted components via `Config.tintIcons` |
| File operations | Desktop.qml:104-133 | Context menu delegates to `DesktopService.executeDesktopFile/openFile/trashFile` |

## CONVENTIONS
- Grid uses `Repeater` bound to `DesktopService.items` (list model)
- Cell calculation: `maxRows = height / cellHeight`, `maxColumns = width / cellWidth`
- Icon index mapped to grid: `x = floor(index / maxRows) * cellWidth`, `y = (index % maxRows) * cellHeight`
- Layer: `WlrLayer.Bottom` with namespace `"yozakura:desktop"`
- Thumbnail refresh uses integer property increment pattern
- Context menu via `Visibilities.contextMenu.openCustomMenu()`

## ANTI-PATTERNS
- Never hardcode icon sizes. Use `Config.desktop.iconSize`, `Config.desktop.spacingVertical`
- Don't modify DesktopService.items directly. Use `DesktopService.moveItem()` for reordering
- Avoid raw Rectangle for icon backgrounds. Use `Styling.srItem()` with appropriate variant
- Don't calculate positions without considering bar position margins (top/bottom/left/right)
