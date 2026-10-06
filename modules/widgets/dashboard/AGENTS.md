# DASHBOARD KNOWLEDGE BASE

## OVERVIEW
Central interactive hub of Yozakura. Tabbed interface with LRU-based lazy-loading for widgets, system controls, media, AI tools, clipboard, notes, and tmux management. Opened via the Notch overlay.

## STRUCTURE
- **Root**: `Dashboard.qml` — Orchestrates LRU logic, tab layout, and open/close animations.
- **Side Tabs**: `DashboardTabRail` (visible tabs in `layout.dashboard.tabs` order, bento edit toggle, settings). Tabs are registered in `DashboardTabs.js`; a tab's index there is stable (`GlobalStates.dashboardCurrentTab`), the config only sets rail order/visibility (settings editor `modules/settings/editors/DashboardTabsEditor.qml`).
- **Sub-tabs** (each a directory):
  - `widgets/`: bento grid. `WidgetRegistry.js` (host-agnostic widgets `{id, url, labelKey, icon, minW/H, maxW/H, defaultW/H}`, `defaultGrid(cols)`; a widget fills its tile and may declare `cellW`, `cellH`, `compact`), `BentoGrid.js` (pure layout: normalize/move/resize/add/remove; `tests/bento-grid.test.cjs`), `BentoView` (grid + edit mode, saves `layout.dashboard.grid` through `commit`), `BentoTile`, `BentoToolbar`, `WidgetPicker` (`tests/bento-edit.test.py`). Widgets: `FullPlayer`, `QuickControls`, `Calendar`, `SpecialsPanel`, `NotificationHistory`, `LevelsColumn`, `WeatherWidget`, `MetricsSummary`.
  - `controls/`: Legacy settings panels — `ShellPanel`, `ThemePanel`, `VariantEditor` — hosted by the schema-driven settings window (`modules/settings`) until each category is migrated (Windows, System, Terminal & Apps, Voice, Updates and Notifications are schema pages now: `modules/settings/schema/{system,terminal,voice,updates,notifications}.js`).
  - `assistant/`: `AssistantTab` (1196 lines) — AI chat interface.
  - `clipboard/`: `ClipboardTab` — Searchable clipboard history. `ClipboardTabBase` holds state/actions, `ClipboardTab` the layout and keys; parts: `ClipboardSearchBar`, `ClipboardList` + `ClipboardItemDelegate` (row, icon, options menu, confirm actions), `ClipboardPreviewPanel` (image/text/link/file previews, metadata); pure helpers in `ClipboardView.js` (`tests/clipboard-view.test.cjs`), behaviour in `tests/clipboard-tab.test.py`.
  - `notes/`: `NotesTab` — state + list actions; `NotesStore` (index.json + note files), `NotesListPanel`/`NoteListItem`/`NoteItemOptions`/`NoteConfirmButtons` (list), `RichTextEditor`+`RichTextFormat`, `MarkdownEditor`+`MarkdownFormat`, `NoteToolButton`. Test: `tests/notes-tab.test.py`.
  - `tmux/`: `TmuxTab` — Tmux session manager (state + actions); `TmuxSearchField` (keyboard flow), `TmuxSessionList` / `TmuxSessionDelegate` / `TmuxSessionOptions` / `TmuxConfirmActions` (rows), `TmuxPreviewPanel` / `TmuxPanesPreview` / `TmuxWindowsBar` (preview), `TmuxProcesses` (tmux calls), `TmuxModel.js` (commands, parsers, row geometry; `tests/tmux-model.test.cjs`, `tests/tmux-tab.test.py`).
  - `emoji/`: `EmojiTab` (934 lines) — Emoji picker with search.
  - `metrics/`: `MetricsTab` (987 lines) — Real-time CPU/RAM/GPU/disk monitoring.
  - `wallpapers/`: `WallpapersTab` / `Wallpaper.qml` — Wallpaper browser and manager. `Wallpaper.qml` (per-screen window + the manager API on `GlobalStates.wallpaperManager`) delegates to `WallpaperScanner` (folder/subfolder scans, fallback), `WallpaperColorPresets`, `MatugenRunner`, `WallpaperCacheJobs` (thumbnails, lock screen frame); rendering is `WallpaperImage` (slots `WallpaperSlot`, `StaticWallpaper`/`VideoWallpaper`, shader `WallpaperTransitionLayer`). `WallpapersTab` = top bar (`WallpaperToggle` x3, `SchemeSelector`), `FilterBar`, grid (`WallpaperGridCell`, `WallpaperGridHighlight`). Tests: `wallpaper-manager.test.py`, `wallpapers-tab.test.py`, `wallpaper-transition.test.py`, `depth-video.test.py`.
  - `kanban/`: Kanban board for task management.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| **Tab loading** | `Dashboard.qml` | `TabLoader` + `shouldTabBeLoaded(index)` LRU logic |
| **System settings** | `controls/ShellPanel.qml` | Bar, dock, notch configuration UI |
| **Theme settings** | `controls/ThemePanel.qml` | Colors, gradients, fonts, opacity |
| **AI chat** | `assistant/AssistantTab.qml` | Multi-provider chat with streaming |
| **Clipboard** | `clipboard/ClipboardTabBase.qml` | State/actions; view parts in `clipboard/Clipboard*.qml` |
| **Notes** | `notes/NotesTab.qml` | Rich text + markdown notes, search; storage in `NotesStore.qml` |

## CONVENTIONS
- **LRU management**: Use `shouldTabBeLoaded(index)` for conditional `Loader.active`. Tabs evicted when exceeding cache limit.
- **Keyboard flow**: Components implement `focusSearchInput()` so root can forward focus on open.
- **UI primitives**: ALWAYS use `StyledRect` variants (`"pane"`, `"internalbg"`, `"focus"`) for containers.
- **Service bindings**: Connect directly to service singletons (`NetworkService`, `Audio`). No prop-drilling.
- **Large files**: Most tabs exceed 900 lines. Edit with care; use targeted line ranges.

## ANTI-PATTERNS
- Creating tab content without LRU integration via `TabLoader`.
- Prop-drilling service state through parent components instead of importing singletons directly.
- Using `Rectangle` instead of `StyledRect` for any container.
