# AGENTS.md: modules/notifications/

## OVERVIEW
Notification popup system built on Quickshell.Services.Notifications. Handles display, grouping, dismissal, and action invocation for notifications.

## BEHAVIOUR (config `notifications.*`, Settings > Notifications)
- `NotificationPolicy.js` (pure, `tests/notification-policy.test.cjs`): where
  popups show (`resolvePresentation`: notch | corner, "auto" by the style of the
  primary panel (bar.panels): islands/corners -> notch, menubar/statusline/
  ribbon/rail/dock -> corner, classic or none -> notch when it sits on the
  bar's edge), corner position, screens filter, per-app rules
  (`matchRules`: mute | priority | alwaysShow | soundOff, `*` wildcards),
  DND schedule (`inSchedule`, windows past midnight), `decide()` (popup,
  sound, timeout), `overflowPopups` (maxVisible), `trimHistory`, `groupKey`.
- `modules/services/Notifications.qml` applies it in `admit()`; `silent` is
  DND (manual `notifications.dnd.enabled` or scheduled; `setDnd`/`toggleDnd`,
  used by the dnd-* actions and the dashboard). `notchPopupList` /
  `cornerPopupList` split popups by presentation.
- Notch presentation: `widgets/defaultview/IslandNotifications.qml` (toast
  "born" from the notch edge while the notch shape grows). Corner
  presentation: `CornerToasts.qml` (+ `CornerToast.qml`), hosted by
  `modules/shell/UnifiedShellPanel.qml` so it clears the bar, frame, dock
  and notch on every edge.
- Renders: `tools/perf/shell_render.py <src> <out> --configs-file=tools/perf/notify_render_configs.json`.

## STRUCTURE
```
modules/notifications/
├── NotificationPolicy.js          # Pure policy (presentation, rules, DND, limits)
├── CornerToasts.qml               # Corner toast stack (presentation "corner")
├── CornerToast.qml                # One toast card (latest of a group + "+N")
├── notification_utils.js          # Time formatting, body processing
├── NotificationDelegate.qml       # Core component (471 lines)
├── NotificationAppIcon.qml        # Icon/image with fallback chain
├── NotificationAnimation.qml     # Dismiss animation (slide + fade)
├── NotificationDismissButton.qml # Dismiss action button
├── NotificationActionButtons.qml # Action button repeater
├── NotificationGroup.qml         # Grouping logic
└── NotificationGroupExpandButton.qml # Expand toggle
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Corner toasts | `CornerToasts.qml` | Toast stack inside the unified shell panel |
| Core display | `NotificationDelegate.qml` | Handles both grouped and single modes |
| Icon handling | `NotificationAppIcon.qml` | Image > appIcon > Icons fallback chain |
| Dismissing | `NotificationAnimation.qml` | Scale + opacity + slide animation |
| Time formatting | `notification_utils.js` | `getFriendlyNotifTimeString()`, `processNotificationBody()` |

## CONVENTIONS

- **Urgency levels**: Use `NotificationUrgency.Normal` / `NotificationUrgency.Critical` from `Quickshell.Services.Notifications`
- **Critical styling**: `Colors.criticalRed`, `Colors.criticalText`, `DiagonalStripePattern` component
- **StyledRect variants**: `"primary"`, `"error"`, `"focus"`, `"common"` for button backgrounds
- **Animation duration**: Read `Config.animDuration` (not hardcoded)
- **Icons singleton**: `Icons.cancel`, `Icons.bell`, `Icons.alert`, `Icons.timer`
- **Delegate modes**: `onlyNotification=true` for popup, `expanded` controls group expansion state

## ANTI-PATTERNS

- **Raw Rectangle for backgrounds**: Use `StyledRect` with appropriate variant
- **Hardcoded animation durations**: Use `Config.animDuration`
- **Missing urgency checks**: Always check `urgency === NotificationUrgency.Critical` for special styling
- **No fallback for missing icons**: Chain `image` -> `appIcon` -> `Icons.*` fallback
- **Direct notification removal**: Use `Notifications.discardNotification(id)` through animation callback
