# NOTCH PANELS (modules/widgets/defaultview/panels)

The resting notch (`DefaultView`) shows a header with segments: the media
title, a timers segment and a downloads segment on the left, a privacy
segment on the right (live activities, `bar.activities.presentation:
"notch"`). Each segment opens **its own panel**; only one is open at a time
and the notch morphs between the collapsed size and the panel's size (the
Notch's own geometry animation; panels crossfade over
`notch.mediaAnimationDuration`, instant with `animDuration: 0`).

| Panel | Trigger | File | Shows |
|---|---|---|---|
| `media` | media title | `MediaPanel.qml` | the player card (`ExpandedMedia`) |
| `transfers` | downloads segment (`tasks`) | `TransfersPanel.qml` | transfers grouped by source: icon, name, bar, sizes · speed, ETA/state, open folder / pause / resume / cancel; combined progress, speed and ETA in the title |
| `timers` | timers segment | `TimerPanel.qml` | timers with ring + remaining; click opens the timer |
| `privacy` | privacy segment | `PrivacyPanel.qml` | recording (stop), microphone apps (mute toggle), camera and screen-sharing apps |
| `voice` | none (`auto`, `modal`) | `VoicePanel.qml` (+ `VoiceBars.qml`) | voice input while listening/transcribing, then the result (`VoiceService.panelOpen`, on the screen it started on); dismissing it cancels the session |

## Opening
`notch.expandOn` (Settings > Shell > Notch > "Open Panels On"):
- `"hover"` (default): resting on a segment for `notch.hoverExpandDelay`
  opens its panel, resting on another switches, leaving the segments and
  the panel closes after `notch.hoverCollapseDelay`. Clicks on segments keep
  their action (stop recording, open timer/download).
- `"click"`: clicking a segment toggles its panel (or switches), a click on
  the header outside the segments closes it. Escape closes it when the notch
  layer has keyboard focus; the resting notch normally has none, so Escape is
  best effort.

`notch.disableHoverExpansion` only removes the media panel (the compact
player is shown instead); activity panels stay available.

## Adding a panel
1. A QML file here whose root is `NotchPanel` (properties `screenName`,
   `revealed`, `maxRows`, `unit`/`padding` spacing, signal
   `closeRequested`). Size yourself with `implicitHeight`; use
   `NotchPanelTitle` for the title row and `NotchActivitiesSection` for
   scrolling lists.
2. One entry in `NotchPanels.js` `PANELS`: `{ id, trigger, url, requires,
   width, maxRows }` (+ optional `auto`, `modal`, see below). `requires` names a key of the availability context
   built in `DefaultView.panelAvailability` (add it there if new), `trigger`
   the header segment that opens it (`IslandHeader.hoverTrigger` /
   `segmentClicked`).

Timing lives in `NotchPanelController.qml` (tests/hover-expansion.test.py);
registry helpers are pure JS (tests/notch-panels.test.cjs); wiring in
tests/notch-activities.test.py and tests/qml-components.test.py.

## Auto and modal panels
- `auto: true`: no trigger; opens by itself as soon as it is available, wins
  over hover/click (segments cannot switch away, leaving does not close it)
  and forces the notch to show. It closes when it becomes unavailable.
- `modal: true`: while open the notch layer takes exclusive keyboard focus
  (the panel gets active focus, Esc reaches `DefaultView`) and a click
  outside closes it (FocusGrab / backdrop, `NotchContent.dismissPanel()`).
- Closing a panel that is still available (Esc, click outside, a launcher or
  dashboard taking the notch) emits the controller's `dismissed(id)` and the
  panel's `dismissed()` signal; a dismissed auto panel stays closed until it
  is unavailable once. `VoicePanel` cancels the voice session there.

