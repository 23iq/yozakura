import QtQuick

// The context of a live preview (Preview.js): a real shell part rendered as
// a picture in Settings. Given to the part's root (BarContent.preview,
// DockContent.preview) and passed down to what reads it; null in the live
// shell. A part in a preview is revealed at once (no auto-hide, no hover
// reveal), takes no input (LivePart makes it inert), and claims nothing
// session-wide (IPC targets, Pomodoro ownership, weather covers, edge
// reservations). `overrides` shows config keys with another value than the
// live config (the picture card of an option not chosen): {"dotted.key":
// value}; every other key follows the live config.
// `samples`: data a part shows instead of a live service or its runtime
// state, {"part.key": value}, read with Preview.sample (the launcher's
// query and the rows of providers that would do I/O, the tab a dashboard
// shows, a sample conversation, the island's track / notifications /
// activities; a null or [] sample means "none"); each key is documented
// where a part reads it.
QtObject {
    property var overrides: ({})
    property var samples: ({})
}
