import QtQuick

// The context of a live preview (Preview.js): a real shell part rendered as
// a picture in Settings. Given to the part's root (BarContent.preview,
// DockContent.preview) and passed down to what reads it; null in the live
// shell. A part in a preview is revealed at once (no auto-hide, no hover
// reveal), takes no input (LivePart makes it inert), and claims nothing
// session-wide (IPC targets, Pomodoro ownership, weather covers, edge
// reservations). `overrides` shows config keys with another value than the
// live config (the picture card of an option not chosen): {"dotted.key":
// value}; every other key follows the live config. `samples`: data shown
// instead of a live service's (Preview.sample): {"player": track,
// "notifications": [...], "activities": [...]}; a part showing a state
// (the island playing a song) gets it here, never from the session.
QtObject {
    property var overrides: ({})
    property var samples: ({})
}
