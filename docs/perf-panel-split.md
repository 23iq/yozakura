# Splitting the unified panel into separately sized layer surfaces

Status: phase 1 (the frame) implemented behind `performance.splitFrame`
(default off); phases 2-5 are design only. Two related window-surface
optimisations ship next to it, also off by default (see "Implemented"
below). Companion to the `audit/smooth-animations` track, which made every
surface's per-frame cost fixed (analytic shadows, no morph-sized layers, no
canvas repaints, render-thread fades) but kept one window per screen.

## Implemented

| Key (all default `false`) | What | Code | Tests |
|---|---|---|---|
| `performance.splitFrame` | Phase 1: the frame and its shadow in `FrameWindow` (Top layer, full screen, empty input mask, no exclusive zone) | `modules/shell/FrameSplit.qml`, `FrameWindow.qml`, `FrameWindowLoader.qml`, `FrameShapeShadow.qml`, `ShadowHoleClip.qml`, `ShapeShadow` clip | `tests/frame-split.test.py` |
| `performance.hidePanelInFullscreen` | The unified panel window unmaps under a fullscreen window while nothing in it has to show | `modules/shell/PanelPresence.js` (every reason), `PanelPresence.qml` | `tests/panel-presence.test.cjs`, `tests/panel-presence.test.py` |
| `performance.compactOsd` | The OSD window sized to the OSD instead of the screen | `modules/shell/osd/OsdWindowBox.js`, `OSD.qml` | `tests/osd-window-box.test.cjs`, `tests/osd-compact.test.py` |

Phase 1 as built (`splitFrame`):

* The phase switch is its own key, `performance.splitFrame`, not the
  `performance.splitSurfaces` of "Phases" below: each phase that lands
  gets its own key until the unified window is gone.
* `FrameSplit` decides who draws the frame. The window does while the
  flag and `bar.frameEnabled` are on and no fullscreen window covers the
  screen. Under a fullscreen window the unified panel draws it again (a
  Top surface sits below a fullscreen client; the frame's restoration
  around a bar revealed in fullscreen must show above it), and the
  window unmaps once that state has held for 250 ms (a quick toggle
  remaps nothing). Handover: the window maps first and the panel stops
  drawing 50 ms later; back to the panel, the panel draws at once.
* Shadows: the frame's own analytic shadow is drawn in `FrameWindow`
  under the frame. The notch, dock and notification-popup shadows
  (`ShapeShadow`) are cut to the frame's rounded hole by a clip uniform in
  `shape_shadow.frag`; the captured bar and live-activity shadows
  (`ShadowCaster`) are clipped to the hole's bounding box
  (`ShadowHoleClip`, a scissor, no layer).
* Visible differences, measured offscreen by `tests/frame-split.test.py`
  (frame window + panel layer composited vs the unified scene, every
  visual language, a contained top bar and a floating left bar, an
  attached notch and dock): with the default (opaque) frame fill the
  shadows are identical; captured bar shadows differ by at most 4/255 on
  about 20 antialiased pixels where they reach the hole's rounded corners
  (bounding-box clip). Text of a contained bar drawn straight on the frame
  (ink, glass: no group box under it) differs on its antialiased glyph
  edges (up to 64/255 in ink, 6/255 in glass, a few hundred pixels): it is
  blended over a transparent window instead of over the frame. A
  translucent frame no longer shows the shadows that passed under it (cut
  at its edge instead). Other programs' Top-layer surfaces and the desktop
  widget editor (Top) can now cover the frame.
* With the flag off `PanelShadows` draws exactly what it drew before
  (before/after `panels_render.py` renders, frame on, contained and
  floating bars, every language: identical but for the bar's live
  content, which also differs between two renders of the same tree).

`hidePanelInFullscreen` is the precondition the "Why" above implies for
fullscreen games and video: an Overlay surface mapped over the fullscreen
client, even fully transparent, blocks direct scanout. The panel maps
again in the same tick when any reason in `PanelPresence.js` holds and
unmaps only after "no reason" has settled. While the bar or the dock is
configured to reveal on edge hover in fullscreen
(`bar.availableOnFullscreen`, `dock.availableOnFullscreen` with
`dock.hoverToReveal`) it never unmaps: a thin hover-strip window that
takes over the edge (the "Hover reveal strips" row below) is not built.

`compactOsd` sizes the OSD window to a box around the OSD (its rest
position, its 14 px slide towards the edge and a theme shadow's reach),
anchored to the edge `EdgeService.osdPlacement` picked and the start edge
across it. The geometry (and the OSD's place and form inside it) is taken
only while the window is unmapped, never during a showing or its
animation, so a layout change made while the OSD is up applies from the
next showing.

## Why

`modules/shell/UnifiedShellPanel.qml` is one full-screen `PanelWindow` per
screen on the `Overlay` layer (`exclusionMode: Ignore`, input limited by a
`mask: Region` built from the notch, dock, activity, toast, strip, corner-pill
and bar hit regions). It hosts the frame, every bar panel, the dock, the
notch, live activities, corner toasts, strips, corner pills and their
shadows (`PanelShadows`).

Qt Quick has no partial updates: whenever anything in that window changes,
the scene graph renders the whole window, a screen-size buffer, and the
compositor composites a screen-size surface. A clock tick, a cava bar, a
hover, the notch's 200 ms morph or the dock's reveal therefore cost one full
frame of a 2560x1440 (or 4K) buffer at the monitor's refresh rate (240 Hz
here). The track above reduced what each frame draws; this design reduces
how much is drawn and composited at all, and lets an idle surface produce no
frames while another animates.

## Target

One layer surface per surface family, each sized to what it can draw (plus
its shadow spill), all on the same output:

| Window | Anchors / size | Layer | Exclusive zone | Input |
|---|---|---|---|---|
| `FrameWindow` | all four edges, full screen | `Top`, mapped first | none (ReservationWindows keep reserving) | empty mask |
| `BarWindow` (one per bar panel) | its edge, `thickness + 2 * frameThickness + spill` deep, its span long (`spanStart`/`spanLength` for aligned/floating panels) | `Top` | none (ReservationWindows) | the panel's `hitRegions` |
| `DockWindow` | its edge, `dockSize + totalMargin + spill` deep, centered, as long as the dock + 2 x cornerSize + spill | `Top` | none | dock hitbox |
| `NotchWindow` | its edge, see "Notch sizing" | `Overlay` | none | silhouette + stem + popup |
| `ActivityWindow` | beside the notch, both hitboxes' bounding box | `Overlay` | none | the two hitboxes |
| `ToastWindow`, `StripsWindow`, `CornerPillsWindow` | their own corners/edges | `Overlay` | none | their content |

`ReservationWindows.qml` already owns every exclusive zone, so no split
window needs one; all split windows keep `exclusionMode: Ignore`.

### Z-order and the shadows

Today everything is ordered by `z` inside one scene: shadows (z 0) < frame
(1) < bars (2) < dock and activities (3) < notch (4) < pills/toasts (5).
Between layer surfaces of the same layer the stacking order is creation
order and is compositor defined, so the split relies on layers instead:

* `FrameWindow`: `Top`, mapped first (wlroots-based compositors, niri and
  Hyprland stack later-mapped layer surfaces of a layer above earlier ones;
  remapping the frame, e.g. after an output change, must remap the bars and
  the dock after it, which `PanelHost` already sequences).
* bars and dock: `Top`, mapped after the frame. Where they overlap the frame
  (contained bars, the attached dock) they draw the same fill, so an
  inverted order would only show at antialiased fillet edges.
* notch, activities, toasts, pills: `Overlay`, always above the `Top` ones.

Shadows move into the window of the surface that casts them, drawn under
that surface (`ShapeShadow` / `ShadowCaster` are already per surface and
sized from the surface's own geometry, so this is a move, not a rewrite).
What changes: a shadow can no longer pass *under* a lower window. Today the
attached notch's shadow ends under the frame so its fillets merge without a
dark seam. In the split, the notch's shadow is drawn in `NotchWindow`, above
the frame. Fix: clip the notch shadow (and the attached dock's) to the
screen's inner area, i.e. `ShapeShadow` gets an optional `clipRect`
(`holeRect` of the frame, published by `ScreenFrameContent`) and multiplies
coverage by "inside clipRect" in the shader. Same for bar shadows over the
frame. This is a uniform, not a layer.

### Notch sizing

Resizing a layer surface per animation frame is the one thing never to do:
every resize is a new buffer, a configure/ack round trip and a commit the
compositor must re-place (and some compositors re-run their layout). The
notch morph would turn into exactly the per-frame reallocation this track
removed inside the scene.

Instead `NotchWindow` is sized to a **grow-only bucket** of the largest
silhouette it has shown, quantised (e.g. 64 px steps along the edge, 32 px
in depth), plus shadow spill and the notification popup:

1. Before a morph starts (`Notch.targetWidth/targetHeight` change, known
   before the animation runs), if the target exceeds the bucket, grow the
   window to the new bucket first, then let the morph run inside it.
2. Shrink lazily: after the notch has rested for a few seconds at a smaller
   size, shrink to its bucket (one resize, while nothing animates).
3. The input mask follows the silhouette exactly (cheap: a region update is
   not a buffer).

The notch's position is not affected: `NotchPlacement` / `EdgeLayout`
already compute the region rect on its edge; the window is anchored to that
edge with a margin of `rect.x` (top/bottom) or `rect.y` (left/right) of the
*bucket*, and `NotchContent` lays out inside it with the remaining offset.
`NotchAvoidance` keeps moving the notch along the edge; a move larger than
the bucket's slack becomes a margin change (one configure, no new buffer).

### Things the single window gives for free today, and their replacement

| Today (one scene) | Split |
|---|---|
| `Visibilities.registerNotch/registerBar/...` read sibling items directly (`PanelHost.bars`, `notchContent`, `dockContent`) | unchanged: they are singletons keyed by screen name; windows register their content items as now |
| `FrameWindow` reads `Visibilities.barPanels[screen]` / `dockPanels` for contain sides and fullscreen restoration | unchanged |
| One `FocusGrab { windows: [unifiedPanel] }` while the notch is open | `windows: [notchWindow, barWindows..., dockWindow]` (clicks on the bar must not dismiss the notch), built from the same registry |
| `backdropArea` full-screen MouseArea while a panel is modal | the modal case keeps a full-screen, fully transparent input-only surface (`Overlay`, mask = whole screen) created only while `needsFullScreenInput`; it never renders after its first frame |
| `LanternScope` (cursor lantern) shared by every surface | one `LanternScope` per window fed with the global pointer from `HoverHandler`s in each window, mapped to screen coordinates by the window's anchor offset |
| Glass backdrop (`HostBackdrop`, `TintedWallpaper`) maps items to the screen with `mapToItem(null, ...)` | add the window's screen offset (anchor margins) to every such mapping; one helper `ScreenSpace.offset(window)` used by the glass, lantern and weather effects |
| `PanelShadows` sees every surface | split into per-window shadow items (see above) |
| Bar popups (`BarPopup` / `PopupWindow`) anchored to the unified window | anchored to their `BarWindow`; `anchor.rect` already comes from the item, so only the window reference changes |
| `ActivityHost` reads the bar and the notch | unchanged (both registered in `Visibilities`) |
| Hover reveal strips at screen edges (bar/notch/dock autohide) | each window keeps a thin strip of its own along its edge while hidden (its input mask), as `DockContent.dockHitbox` already does |

### Multi-monitor

Same `Variants { model: Quickshell.screens }` per window family in
`shell.qml`. `PanelHost` keeps owning the list of bars per screen and
creates one `BarWindow` per entry instead of one item per entry.

## Phases

Each phase is independently shippable behind `performance.splitSurfaces`
(default off until the last phase lands), with the unified window as the
fallback so a regression is one config switch away.

1. **Frame.** `FrameWindow` (static most of the time) with its analytic
   shadow. Win: the frame and its shadow stop being re-rendered when
   anything else animates. Risk: low (no input, no focus). Done, behind
   `performance.splitFrame` (see "Implemented").
2. **Dock.** `DockWindow` (fixed size per dock length bucket; the reveal is
   a translate + fade inside it). Shadow clipped to the frame hole.
3. **Bars.** One `BarWindow` per panel; popups re-anchored; focus grab list.
   The captured `ShadowCaster` of a bar now captures a bar-sized window's
   item, so its cost is bounded by the bar.
4. **Notch + activities.** Bucketed `NotchWindow`, `ActivityWindow`,
   `FocusGrab` across windows, modal input surface, lantern/glass offsets.
5. **Toasts, strips, corner pills**, then remove the unified window.

## Verification

* Offscreen renders before/after per phase in all five languages
  (`tools/render/panels_render.py` with a split-surfaces layout,
  `island_render.py`): pixel identical except antialiasing at window
  boundaries.
* `tests/panels.test.py` style harness per window: geometry of each window
  for every edge, frame thickness, contained bar and notch style; input
  masks; the notch bucket grows before a morph and never during it.
* Frame cost: `QSG_RENDER_TIMING=1` (render + swap per window) and the
  compositor's damage/repaint stats (Hyprland `debug:damage_tracking`,
  niri `debug.wait-for-frame-completion-before-queueing`) with a clock tick,
  a cava visualizer and a notch open/close loop; target: an idle window
  renders 0 frames while another animates, and the notch morph renders a
  notch-sized buffer only.
