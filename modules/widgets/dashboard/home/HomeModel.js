.pragma library

// Pure helpers of the composed dashboard home (tests/dashboard-home-model.test.cjs).

// Seconds -> "m:ss" (or "h:mm:ss").
function formatTime(seconds) {
    var s = Math.max(0, Math.floor(Number(seconds) || 0));
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var mm = h > 0 && m < 10 ? "0" + m : "" + m;
    return (h > 0 ? h + ":" : "") + mm + ":" + (sec < 10 ? "0" : "") + sec;
}

// "artist · album", skipping the empty parts.
function artistLine(artist, album) {
    return [artist, album].filter(function (s) {
        return s && String(s).trim() !== "";
    }).join(" · ");
}

// Notification text (may hold markup) -> one plain line.
function plainLine(text) {
    return String(text || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
}

// Name of the first connected device of BluetoothService.friendlyDeviceList.
function connectedDevice(list) {
    var l = list || [];
    for (var i = 0; i < l.length; i++) {
        if (l[i] && l[i].connected)
            return l[i].name || "";
    }
    return "";
}

// One notification group -> its one-line row: {text, count, app, icon,
// image, ids}. The line is the latest notification ("summary · body", or
// whichever is set); `count` how many the app has; `ids` to clear them.
function groupRow(group) {
    var list = group && group.notifications ? group.notifications : [];
    var latest = list.length > 0 ? list[list.length - 1] : null;
    var app = group ? group.appName || "" : "";
    if (!latest)
        return { text: app, count: 0, app: app, icon: "", image: "", ids: [] };
    var parts = [plainLine(latest.summary), plainLine(latest.body)].filter(function (s) {
        return s !== "";
    });
    return {
        text: parts.length > 0 ? parts.join(" · ") : (latest.appName || app),
        count: list.length,
        app: latest.appName || app,
        icon: latest.cachedAppIcon || latest.appIcon || "",
        image: latest.cachedImage || latest.image || "",
        ids: list.map(function (n) {
            return n.id;
        })
    };
}

// Image source of a row's app mark: the app icon from the icon theme, else
// the notification image, else none (the Avatar shows the app's initials).
function avatarSource(row) {
    var src = row.icon || row.image || "";
    if (src === "")
        return "";
    if (src.charAt(0) === "/")
        return "file://" + src;
    return /^[a-z]+:/.test(src) ? src : "image://icon/" + src;
}

// Pipewire peak (linear amplitude 0..1) -> meter fraction on a -60..0 dB
// scale, so speech reads as a lively bar instead of a sliver.
function meterLevel(peak) {
    var p = Number(peak) || 0;
    if (p <= 0.001)
        return 0;
    var db = 20 * Math.log(Math.min(1, p)) / Math.LN10;
    return Math.max(0, Math.min(1, (db + 60) / 60));
}
