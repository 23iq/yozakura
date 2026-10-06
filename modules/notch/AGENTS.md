# AGENTS.md - modules/notch/

## OVERVIEW
Dynamic island UI with StackView navigation, themes (default/island), and notification popup system.

## STRUCTURE

| File | Purpose |
|------|---------|
| `Notch.qml` | Core dynamic island: StackView, rounded corners with mask, theme rendering, animations |
| `NotchContent.qml` | Screen-specific wrapper: hover detection, reveal logic, persistent Loaders, visibility bindings |
| `NotchSilhouette.qml` / `NotchOutline.qml` | Background (attached mask + outline, island) on any edge; mask/outline drawn for top and turned for a side edge |
| `NotchShape.js` | Pure edge math: radii, corner sizes, hide offset, view placement, hover strip (`tests/notch-shape.test.cjs`) |
| `NotchPlacement.qml` | Region rect on its edge via `EdgeLayout.notchRect` (align, side bar/dock/frame offset) + hover strip |
| `NotchAnimationBehavior.qml` | Reusable animation behavior component |
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
- Avoid direct stack manipulation - use `Visibilities` service signals (onLauncherChanged, onDashboardChanged, etc.)
- Don't skip `Qt.callLater()` when pushing to StackView from Connections - prevents async list modification issues