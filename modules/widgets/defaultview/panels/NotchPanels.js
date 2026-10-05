.pragma library

// Registry of the notch's expanded panels. Each collapsed segment of the
// notch header has a trigger id; hovering (bar notch.expandOn "hover") or
// clicking ("click") it opens the panel registered for that trigger, one at
// a time, and the notch morphs between collapsed and panel sizes.
//
// Adding a panel = one QML file in this directory (root: NotchPanel) + one
// entry below. Entry fields:
//   id        unique panel id
//   trigger   header segment that opens it ("media" = the media title,
//             "tasks" = downloads segment, "timers", "privacy", ...)
//   url       QML file, relative to this directory
//   requires  key of the availability context that must be truthy/non-zero
//             (see availability()); the panel closes when it goes away
//   width     preferred width in px; 0 = Config.notch.expandedMediaWidth
//   maxRows   list height before the panel scrolls, in rows of about two
//             text lines (0 = panel default)
//   auto      (optional) opens by itself while available, without a
//             trigger, and stays until it becomes unavailable or the user
//             dismisses it (hover/click on segments cannot switch away)
//   modal     (optional) while open the notch takes keyboard focus and a
//             click outside dismisses it (Esc always does)
// Unit tested in tests/notch-panels.test.cjs.

var PANELS = [
    {
        id: "media",
        trigger: "media",
        url: "MediaPanel.qml",
        requires: "player",
        width: 0,
        maxRows: 0
    },
    {
        id: "transfers",
        trigger: "tasks",
        url: "TransfersPanel.qml",
        requires: "transfers",
        width: 0,
        maxRows: 7
    },
    {
        id: "timers",
        trigger: "timers",
        url: "TimerPanel.qml",
        requires: "timers",
        width: 0,
        maxRows: 4
    },
    {
        id: "privacy",
        trigger: "privacy",
        url: "PrivacyPanel.qml",
        requires: "privacy",
        width: 0,
        maxRows: 6
    },
    {
        // Voice input: live while listening/transcribing, then the result
        id: "voice",
        trigger: "",
        url: "VoicePanel.qml",
        requires: "voice",
        width: 480,
        maxRows: 0,
        auto: true,
        modal: true
    }
];

var EXPAND_MODES = ["hover", "click"];

function byId(id) {
    for (var i = 0; i < PANELS.length; i++)
        if (PANELS[i].id === id)
            return PANELS[i];
    return null;
}

function indexOf(id) {
    for (var i = 0; i < PANELS.length; i++)
        if (PANELS[i].id === id)
            return i;
    return -1;
}

// Panel id opened by a header segment trigger ("" when none)
function panelFor(trigger) {
    if (!trigger)
        return "";
    for (var i = 0; i < PANELS.length; i++)
        if (PANELS[i].trigger === trigger)
            return PANELS[i].id;
    return "";
}

// ctx: { player: bool, transfers: n, timers: n, privacy: n, ... }
// Returns { panelId: bool }
function availability(ctx) {
    var c = ctx || {};
    var out = {};
    for (var i = 0; i < PANELS.length; i++) {
        var v = c[PANELS[i].requires];
        out[PANELS[i].id] = typeof v === "number" ? v > 0 : !!v;
    }
    return out;
}

// First auto panel that is available and not dismissed ("" when none)
function autoPanel(available, dismissed) {
    for (var i = 0; i < PANELS.length; i++) {
        var p = PANELS[i];
        if (p.auto && available && available[p.id] && p.id !== dismissed)
            return p.id;
    }
    return "";
}

function isAuto(id) {
    var p = byId(id);
    return !!(p && p.auto);
}

function isModal(id) {
    var p = byId(id);
    return !!(p && p.modal);
}

// Width the notch takes for a panel (fallback: the expanded media width)
function widthFor(id, defaultWidth) {
    var p = byId(id);
    return p && p.width > 0 ? p.width : defaultWidth;
}

function expandMode(value) {
    return EXPAND_MODES.indexOf(value) !== -1 ? value : "hover";
}

// Click mode: clicking a segment toggles its panel (switching from another)
function toggled(open, id, available) {
    if (!id || open === id)
        return "";
    return available && available[id] ? id : open;
}
