# AGENTS.md - modules/widgets/overview/

## OVERVIEW
Mission Control-style workspace overview. Two layout modes: grid (default) and scrolling. Shows all workspaces with window previews, supports window dragging between workspaces, and fuzzy search.

## STRUCTURE

| File | Role |
|------|------|
| `OverviewPopup.qml` | PanelWindow container. Handles search input, backdrop, visibility state |
| `OverviewView.qml` | Loader switching between grid/scrolling layouts based on `GlobalStates.compositorLayout` |
| `Overview.qml` | Standard grid overview. Workspace grid with scaled window previews |
| `ScrollingOverview.qml` | Vertical scrolling layout. Auto-centers on active workspace |
| `ScrollingWorkspace.qml` | Individual workspace in scrolling mode. Handles horizontal scroll for window overflow |
| `OverviewWindow.qml` | Window delegate in grid view. Drag, click (activate), middle click (close), search highlighting |
| `OverviewActivation.qml` | Singleton: "close the overview and activate this window" (click on a preview, Enter on a match). Sends focuswindow at once and again after every overview surface unmapped (Hyprland refuses focus under the exclusive layer) |
| `OverviewWindowRows.qml` | `ListModel` of the windows, keyed by address (kit `KeyedSync.js` edits): previews live as long as their window (the window list is pushed on every compositor event). Delegates read `rows.byKey[key]` from the `key` / `rows` roles |
| `OverviewStrip.qml` (+ `OverviewStripCell`, `OverviewStripWindows`) | `overview.style = strip`: horizontal filmstrip, selected workspace centered; arrows/wheel move, Enter switches, typing searches. Reuses `OverviewWindow`, whose parent chain (dragArea > window > windowSpace > belt > root) must stay |
| `OverviewStyles.js` | Style registry (`resolve(style, layout)`; scrolling layout wins); `StripMath.js`, `OverviewSearch.js` are the pure logic |

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Entry point | `OverviewPopup.qml` | PanelWindow with layershell, search input, loads OverviewView |
| Grid layout | `Overview.qml` | Workspace grid, window positioning, active indicator |
| Scrolling layout | `ScrollingOverview.qml` | Vertical Flickable, workspace list, auto-scroll to active |
| Window rendering | `OverviewWindow.qml` (grid) + `OverviewWindowFace.qml` (shared with the scrolling view) | ScreencopyView preview, outline, tooltip in the face; drag handling in the window |
| Search logic | `Overview.qml:60-134` | Fuzzy matching algorithm, score calculation |
| Workspace groups | `Overview.qml:31` | `workspaceGroup = floor((activeWorkspaceId - 1) / workspacesShown)` |

## CONVENTIONS

- Uses `YozdService.dispatch()` for Hyprland commands (workspace switch, window move/focus)
- A single click on a workspace (pick, the overview stays open) goes through `YozdService.switchWorkspaceKeepCursor()` once the double-click interval has passed (a double click is only the plain switch, never a pick first: a second `workspace N` would toggle back with workspace_back_and_forth): Hyprland warps the pointer to the middle of the target monitor when the workspace lives on another output, yozd (`workspace switch <id> keep-cursor`) switches and puts it back in one batch. Switches that close the overview and go there (double click, double tap, Enter) are plain `workspace N`: with follow_mouse the keyboard focus must follow
- Uses `CompositorData.windowList` and `CompositorData.monitors` for window data
- Uses `ToplevelManager.toplevels` + `ScreencopyView` for live window previews
- Built from the UI kit: `Type.accent` for the active / selected outline (`WorkspaceRing`), `Scrim` backdrop, `Look.radius` roles (workspaces "box", windows "small")
- Config keys: `Config.overview.scale`, `rows`, `columns`, `workspaceSpacing`
- Two layouts via conditional Component in `OverviewView`: `GlobalStates.compositorLayout === "scrolling"`
- Drag reparenting in scrolling mode uses `dragOverlay` Item to escape clipping
- Search in child components synced via property binding from parent

## ANTI-PATTERNS

- Don't hardcode workspace dimensions. Use `monitorData.scale`, `barPosition`, `barReserved` to calculate
- Don't use window position directly. Scale by `Config.overview.scale` for overview display
- Don't close the overview and dispatch `focuswindow` by hand: call `OverviewActivation.activate(address)` (one click on a preview does; there is no double click)
- Don't put the raw window array into a `Repeater`: use `OverviewWindowRows` (a rebuilt preview loses the click or drag in progress)
- Don't drop `Behavior on x/y` from a window preview: with it the `x = ...` assignments after a drag go through the interceptor and leave the `x`/`y` bindings in place (previews are no longer rebuilt, so a lost binding would stick; `tests/overview-click.test.py` checks it)
- Don't calculate workspace ID from mouse position without bounds checking
- Don't forget to reset `horizontalScrollOffset` when workspace windows change in scrolling mode