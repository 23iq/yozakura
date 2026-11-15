.pragma library

// Sample data the live previews show instead of a live service's
// (PreviewContext.samples, Preview.sample): the island's states, the
// notification toasts. Believable content in one place, so a stage and a
// picture show the same song, message and timer. Pure (tests/
// live-preview.test.cjs); what depends on the config (a timer's label as
// the shell writes it) is built by the caller and passed in.

// The island's states (Island stage chips): id, its label, the card a
// click on the island opens
var STATES = [
    { "id": "rest", "label": "prefs.notch.state.rest", "section": "idle" },
    { "id": "media", "label": "prefs.notch.state.media", "section": "media" },
    { "id": "notification", "label": "prefs.notch.state.notification", "section": "activities" },
    { "id": "timer", "label": "prefs.notch.state.timer", "section": "activities" }
];

// A playing track (an MPRIS player as MprisController hands it); `art`: an
// image URL for its cover
function track(art) {
    return {
        "trackTitle": "Hanami Night",
        "trackArtist": "Sakura Trio",
        "trackAlbum": "Spring Tapes",
        "trackArtUrl": art || "",
        "isPlaying": true,
        "position": 104,
        "length": 243,
        "identity": "Music",
        "dbusName": "org.mpris.MediaPlayer2.music",
        "desktopEntry": "",
        "canControl": true,
        "canSeek": true,
        "canGoNext": true,
        "canGoPrevious": true,
        "canTogglePlaying": true
    };
}

// Still visualizer bars (0..1)
var LEVELS = [0.45, 0.85, 0.6, 1.0, 0.5, 0.75, 0.35, 0.65];

// A message, `ago` ms old at `now` (notifications as Notifications lists
// them: notchPopupList, a popup group's notifications)
function message(now, ago, id, summary, body) {
    return {
        "id": id,
        "appName": "Telegram",
        "appIcon": "telegram",
        "cachedAppIcon": "",
        "image": "",
        "cachedImage": "",
        "summary": summary,
        "body": body,
        "time": now - ago,
        "urgency": 1,
        "isCached": false,
        "actions": [
            { "identifier": "reply", "text": "Reply" },
            { "identifier": "read", "text": "Mark as read" }
        ]
    };
}

// The toast's notifications: the newest last; `grouped` (group by app):
// two older ones of the same app behind it
function messages(now, grouped) {
    var newest = message(now, 60000, -1, "Yuki", "Dinner at eight? I booked the place by the river.");
    if (!grouped)
        return [newest];
    return [
        message(now, 1800000, -3, "Yuki", "Are you around tonight?"),
        message(now, 600000, -2, "Yuki", "The river place has a table at eight."),
        newest
    ];
}

// A popup group as CornerToasts / StripsView get it (time: its newest)
function group(now, grouped) {
    return { "appName": "Telegram", "time": now - 60000, "notifications": messages(now, grouped) };
}

// Popup groups by app (Notifications.popupGroupsByAppName): the message
// and an older reminder of another app
function groups(now, grouped) {
    var reminder = {
        "id": -4,
        "appName": "Calendar",
        "appIcon": "x-office-calendar",
        "summary": "Review",
        "body": "Today at 22:30",
        "time": now - 300000,
        "urgency": 1,
        "isCached": false,
        "actions": []
    };
    return {
        "Telegram": group(now, grouped),
        "Calendar": { "appName": "Calendar", "time": reminder.time, "notifications": [reminder] }
    };
}

// An OSD showing (the style components' and the bar's inline OSD's
// properties): the volume at 62 %
function osd() {
    return { "kind": "volume", "value": 0.62, "shown": true };
}

// A running timer (TimersService.timers' shape): 16:20 of 25 minutes left
function timer(now) {
    return {
        "id": "preview",
        "name": "Focus",
        "state": "running",
        "leftMs": 980000,
        "totalMs": 1500000,
        "pomodoro": true,
        "ringing": false,
        "createdAt": now - 520000
    };
}

// The samples of an island state (PreviewContext.samples): "rest" shows
// nothing playing, no notification and no activity (the island as it rests:
// notch.noMediaDisplay); `timerActivity` is the timer as the shell's
// activity provider makes it (TimerActivity.timerActivity(timer(now)))
function island(state, now, art, timerActivity) {
    return {
        "player": state === "media" ? track(art) : null,
        "levels": LEVELS,
        "focusedTitle": "",
        "notifications": state === "notification" ? messages(now, false) : [],
        "activities": state === "timer" && timerActivity ? [Object.assign({ "source": "timers" }, timerActivity)] : []
    };
}
