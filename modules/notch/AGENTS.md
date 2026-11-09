# AGENTS.md - modules/notch/

## OVERVIEW
Dynamic island UI with StackView navigation, themes (default/island), and notification popup system.

## STRUCTURE

| File | Purpose |
|------|---------|
| `Notch.qml` | Core dynamic island: StackView, rounded corners with mask, theme rendering, animations |
| `NotchContent.qml` | Screen-specific wrapper: hover detection, reveal logic, persistent Loaders, visibility bindings |
| `NotchSilhouette.qml` / `NotchOutline.qml` | Background (attached: rounded body + two cornerSize concave pieces, no layer follows the morph; island) on any edge; outline is a Shapes path drawn for top and turned for a side edge |
| `NotchShape.js` | Pure edge math: radii, corner sizes, hide offset, view placement, hover strip (`tests/notch-shape.test.cjs`) |
| `NotchPlacement.qml` | Region rect on its edge via `EdgeLayout.notchRect` (align, side bar/dock/frame offset) + hover strip |
| `NotchAvoid.js` / `NotchAvoidance.qml` | A grown notch (hover, panel, notification, activity, hosted view) never covers the modules of a bar on its edge: stays, slides between the bar groups, or drops past the bar; one the pointer grew stays put (`anchored`), a dock-like bar parts around it (`modules/bar/panels/styles/DockSplit.js`); hover stem from the resting place (`tests/notch-avoid.test.cjs`, `tests/dock-split.test.cjs`, `tests/notch-hover-avoid.test.py`) |
| `NotchHoverHold.qml` | Pointer presence over the whole silhouette (+ tolerance) held for `notch.hoverCollapseDelay`; drives the pill and holds open panels |
| `NotchAnimationBehavior.qml` | Open/close scale + fade of a notch view (dashboard) on render-thread Animators; `visible` holds through the leave motion (`tests/notch-animation-behavior.test.py`) |
| `NotchNotificationView.qml` | Notification display with StackView navigation, timestamps, hover states |

## WHERE TO LOOK

- **StackView navigation**: `Notch.qml:326-452` - push/pop transitions with scale+opacity animations
- **Theme rendering**: `Notch.qml:79-142` (default) and `Notch.qml:232-285` (island) - StyledRect with mask system
- **Reveal logic**: `NotchContent.qml:101-124` - auto-hide based on `keepHidden`, bar position, fullscreen
- **Hover detection**: `NotchContent.qml:95-148` - delay timer prevents flickering on mouse leave
- **Notification popup**: `NotchContent.qml:306-411` - styled popup below notch with StackView
- **Notification navigation**: `NotchNotificationView.qml:202-291` - wheel/scroll navigation, direction-aware transitions

## CONVENTIONS

Follows parent AGENTS.md. No additional conventions.

## ANTI-PATTERNS

- Side edges (`notch.position` left/right): never rotate content. The header re-lays upright (`IslandHeader.vertical`, `IslandRail`, stacked segment labels via `NotchActivities.stackedLabel`) and panels/views open beside it toward the center
- Never hardcode notch dimensions - use `Config.notchStyle` (styles/NotchStyles.js registry: attached/island/pill), `Config.roundness`, `Config.notchPosition`, `notch.align` via `EdgeService.notchRect`
- Notifications in the notch: `NotchNotificationCard` (card) or `CompactNotification` (compact), picked by `NotchNotificationStyles.js`; island activities order/side/enable: `modules/widgets/defaultview/activities/ActivityRegistry.js`
- Morph cost: nothing whose size follows the morph may be a layer, Canvas or captured shadow (the shadow is `ShapeShadow` in `PanelShadows`, fed by `NotchContent.silhouetteRect`); see `docs/perf-panel-split.md` for the window split
- Hover: never a hover-enabled `MouseArea` over the notch to detect presence (children take it); use the container `HoverHandler` (`NotchContent`) and the held state. Size, radius and avoidance moves share `Motion.morph`; no per-state easing switches
- Avoid direct stack manipulation - use `Visibilities` service signals (onLauncherChanged, onDashboardChanged, etc.)
- Don't skip `Qt.callLater()` when pushing to StackView from Connections - prevents async list modification issues